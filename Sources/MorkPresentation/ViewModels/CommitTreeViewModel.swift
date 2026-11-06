import MorkDomain
import Foundation
import Observation

struct PreparedBlob: Sendable {
    let content: FileRevisionContent
    let document: DiffDocument?

    static func make(_ content: FileRevisionContent) -> PreparedBlob {
        guard case let .text(text, _) = content else { return PreparedBlob(content: content, document: nil) }
        return PreparedBlob(content: content, document: DiffDocument(lines: DiffLine.content(text), tabWidth: DiffMetrics.standard.tabWidth))
    }

    var cost: Int {
        guard case let .text(_, count) = content else { return 1 }
        return max(count, 1) * 3
    }
}

@MainActor
final class BlobContentCache {
    static let defaultCapacity = 16 * 1024 * 1024

    let capacity: Int
    private(set) var totalCost = 0
    private var entries: [String: (blob: PreparedBlob, cost: Int)] = [:]
    private var order: [String] = []

    init(capacity: Int = defaultCapacity) {
        self.capacity = capacity
    }

    func blob(for id: String) -> PreparedBlob? {
        guard let entry = entries[id] else { return nil }
        if order.last != id {
            order.removeAll { $0 == id }
            order.append(id)
        }
        return entry.blob
    }

    func insert(_ blob: PreparedBlob, for id: String, cost: Int) {
        guard cost <= capacity else { return }
        if let old = entries[id] {
            totalCost -= old.cost
            order.removeAll { $0 == id }
        }
        entries[id] = (blob, cost)
        order.append(id)
        totalCost += cost
        while totalCost > capacity, !order.isEmpty {
            let evicted = order.removeFirst()
            totalCost -= entries.removeValue(forKey: evicted)?.cost ?? 0
        }
    }
}

@MainActor
@Observable
public final class CommitTreeViewModel: Identifiable {
    public nonisolated static let loadingIndicatorDelay: Duration = .milliseconds(150)
    public nonisolated static let hoverPrefetchDelay: Duration = .milliseconds(80)

    public private(set) var commit: Commit
    public private(set) var root: Loadable<[TreeEntry]> = .idle
    public private(set) var rows: [TreeRow] = []
    public private(set) var selectedPath: String?
    public private(set) var content: Loadable<FileRevisionContent> = .idle
    public private(set) var displayedPath: String?
    public private(set) var showsLoadingIndicator = false
    internal private(set) var document: DiffDocument?
    public var errorMessage: String?
    public var notice: Notice?
    public var filter = "" {
        didSet { if filter != oldValue { rebuildRows() } }
    }

    private let dependencies: CommitTreeDependencies
    private let openInEditor: @MainActor (URL) async -> Void
    private let temporaryDirectory: URL
    private let sleep: @Sendable (Duration) async throws -> Void
    @ObservationIgnored let blobs = BlobContentCache()
    @ObservationIgnored private var blobTasks: [String: Task<Result<PreparedBlob, Error>, Never>] = [:]
    @ObservationIgnored private var hoverTask: Task<Void, Never>?
    @ObservationIgnored private var indicatorTask: Task<Void, Never>?
    @ObservationIgnored private var isLoadingContent = false
    @ObservationIgnored private var children: [String: Loadable<[TreeEntry]>] = [:]
    @ObservationIgnored private var expanded: Set<String> = []
    @ObservationIgnored private var entries: [String: TreeEntry] = [:]
    @ObservationIgnored private var sizes: [String: String] = [:]
    @ObservationIgnored private var folderTasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var contentTask: Task<Void, Never>?
    @ObservationIgnored private var rootTask: Task<Void, Never>?

    public init(
        commit: Commit,
        dependencies: CommitTreeDependencies,
        temporaryDirectory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("mork-revisions"),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        openInEditor: @escaping @MainActor (URL) async -> Void
    ) {
        self.commit = commit
        self.dependencies = dependencies
        self.temporaryDirectory = temporaryDirectory
        self.sleep = sleep
        self.openInEditor = openInEditor
    }

    public var selectedEntry: TreeEntry? { selectedPath.flatMap { entries[$0] } }
    public var command: String { "git ls-tree -z -l \(commit.shortHash)" }

    public func load() async {
        loadRoot()
        await rootTask?.value
    }

    public func show(_ commit: Commit) {
        if commit == self.commit {
            if case .idle = root { loadRoot() }
            return
        }
        self.commit = commit
        reset()
        loadRoot()
    }

    public func waitForLoads() async {
        await rootTask?.value
        while let task = folderTasks.values.first {
            await task.value
        }
    }

    private func loadRoot() {
        rootTask?.cancel()
        root = .loading
        let load = dependencies.loadTreeEntries
        let revision = commit.hash
        rootTask = Task { [weak self] in
            let result: Loadable<[TreeEntry]>
            var texts: [String: String] = [:]
            do {
                let loaded = try await load.execute(revision: revision, directory: "")
                texts = await Self.sizeTexts(loaded)
                result = .loaded(loaded)
            } catch {
                result = .failed(error.localizedDescription)
            }
            guard let self, !Task.isCancelled else { return }
            if case let .loaded(loaded) = result { self.remember(loaded, sizes: texts) }
            self.root = result
            self.rebuildRows()
            if case let .loaded(loaded) = result { self.loadExpandedFolders(in: loaded) }
        }
    }

    private func reset() {
        contentTask?.cancel()
        contentTask = nil
        hoverTask?.cancel()
        hoverTask = nil
        folderTasks.values.forEach { $0.cancel() }
        folderTasks = [:]
        children = [:]
        entries = [:]
        sizes = [:]
        selectedPath = nil
        finishLoading()
        display(.idle, document: nil, path: nil)
    }

    public func isExpanded(_ entry: TreeEntry) -> Bool {
        expanded.contains(entry.path)
    }

    public func toggle(_ entry: TreeEntry) {
        guard entry.isDirectory, case .loaded = root else { return }
        if expanded.remove(entry.path) != nil {
            rebuildRows()
            return
        }
        expanded.insert(entry.path)
        if case .loaded = children[entry.path] {
            rebuildRows()
            return
        }
        loadFolder(entry.path)
        rebuildRows()
    }

    private func loadExpandedFolders(in loaded: [TreeEntry]) {
        for entry in loaded where entry.isDirectory && expanded.contains(entry.path) && children[entry.path] == nil {
            loadFolder(entry.path)
        }
    }

    private func loadFolder(_ path: String) {
        children[path] = .loading
        let load = dependencies.loadTreeEntries
        let revision = commit.hash
        folderTasks[path] = Task { [weak self] in
            let result: Loadable<[TreeEntry]>
            var texts: [String: String] = [:]
            do {
                let loaded = try await load.execute(revision: revision, directory: path)
                texts = await Self.sizeTexts(loaded)
                result = .loaded(loaded)
            } catch {
                result = .failed(error.localizedDescription)
            }
            guard let self, !Task.isCancelled else { return }
            if case let .loaded(loaded) = result { self.remember(loaded, sizes: texts) }
            self.children[path] = result
            self.folderTasks[path] = nil
            if self.expanded.contains(path) { self.rebuildRows() }
            if case let .loaded(loaded) = result { self.loadExpandedFolders(in: loaded) }
        }
    }

    public func waitForFolders() async {
        for task in Array(folderTasks.values) { await task.value }
    }

    public func select(path: String?) {
        guard path != selectedPath else { return }
        contentTask?.cancel()
        contentTask = nil
        selectedPath = path
        guard let path, let entry = entries[path], entry.hasContent else {
            finishLoading()
            display(.idle, document: nil, path: nil)
            return
        }
        defer { prefetchNeighbors(of: path) }
        if let ready = blobs.blob(for: entry.object) {
            finishLoading()
            display(.loaded(ready.content), document: ready.document, path: path)
            return
        }
        if displayedPath == nil, content != .loading { content = .loading }
        startLoading()
        let task = blobTask(for: entry)
        contentTask = Task { [weak self] in
            let result = await task.value
            guard let self, !Task.isCancelled, self.selectedPath == path else { return }
            self.finishLoading()
            switch result {
            case let .success(ready): self.display(.loaded(ready.content), document: ready.document, path: path)
            case let .failure(error): self.display(.failed(error.localizedDescription), document: nil, path: path)
            }
        }
    }

    public func waitForContent() async {
        await contentTask?.value
    }

    public func hover(path: String?) {
        hoverTask?.cancel()
        hoverTask = nil
        guard let path, let entry = entries[path], entry.hasContent, needsLoad(entry) else { return }
        let sleep = sleep
        hoverTask = Task { [weak self] in
            try? await sleep(Self.hoverPrefetchDelay)
            guard !Task.isCancelled, let self else { return }
            _ = self.blobTask(for: entry)
        }
    }

    public func waitForPrefetches() async {
        await hoverTask?.value
        while let task = blobTasks.values.first {
            _ = await task.value
        }
    }

    private func prefetchNeighbors(of path: String) {
        guard let index = rows.firstIndex(where: { $0.id == path }) else { return }
        for neighbor in [index - 1, index + 1] where rows.indices.contains(neighbor) {
            if let entry = rows[neighbor].entry, entry.hasContent, needsLoad(entry) { _ = blobTask(for: entry) }
        }
    }

    private func needsLoad(_ entry: TreeEntry) -> Bool {
        blobTasks[entry.object] == nil && blobs.blob(for: entry.object) == nil
    }

    private func blobTask(for entry: TreeEntry) -> Task<Result<PreparedBlob, Error>, Never> {
        if let task = blobTasks[entry.object] { return task }
        let load = dependencies.loadFileAtRevision
        let blob = BlobReference.object(entry.object, path: entry.path)
        let size = entry.size
        let id = entry.object
        let task = Task { [weak self] () -> Result<PreparedBlob, Error> in
            let result: Result<PreparedBlob, Error>
            do {
                let content = try await load.execute(blob: blob, size: size, limit: FileRevisionContent.textLimit)
                result = .success(await Task.detached(priority: .userInitiated) { PreparedBlob.make(content) }.value)
            } catch {
                result = .failure(error)
            }
            self?.finishBlob(id, result)
            return result
        }
        blobTasks[id] = task
        return task
    }

    private func finishBlob(_ id: String, _ result: Result<PreparedBlob, Error>) {
        blobTasks[id] = nil
        if case let .success(ready) = result { blobs.insert(ready, for: id, cost: ready.cost) }
    }

    private func display(_ next: Loadable<FileRevisionContent>, document: DiffDocument?, path: String?) {
        if displayedPath != path { displayedPath = path }
        if self.document != document { self.document = document }
        if content != next { content = next }
    }

    private func startLoading() {
        isLoadingContent = true
        indicatorTask?.cancel()
        let sleep = sleep
        indicatorTask = Task { [weak self] in
            try? await sleep(Self.loadingIndicatorDelay)
            guard !Task.isCancelled, let self, self.isLoadingContent else { return }
            self.showsLoadingIndicator = true
        }
    }

    private func finishLoading() {
        isLoadingContent = false
        indicatorTask?.cancel()
        indicatorTask = nil
        if showsLoadingIndicator { showsLoadingIndicator = false }
    }

    public func saveSelected() async {
        guard let entry = selectedEntry, entry.hasContent,
              let destination = await dependencies.panels.chooseDestination(suggestedName: entry.name) else { return }
        do {
            try await dependencies.saveFileAtRevision.execute(blob: .commit(commit.hash, entry.path), destination: destination)
            notice = Notice(title: "File Saved", message: "\(entry.path) as of \(commit.shortHash) was saved to \(destination.path) (git show \(commit.shortHash):\(ShellWords.quote(entry.path))).")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func openSelectedInEditor() async {
        guard let entry = selectedEntry, entry.hasContent else { return }
        let destination = temporaryCopy(of: entry)
        do {
            try await dependencies.saveFileAtRevision.execute(blob: .commit(commit.hash, entry.path), destination: destination)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        await openInEditor(destination)
    }

    func temporaryCopy(of entry: TreeEntry) -> URL {
        temporaryDirectory.appendingPathComponent(commit.shortHash).appendingPathComponent(entry.path)
    }

    public func close() {
        rootTask?.cancel()
        contentTask?.cancel()
        hoverTask?.cancel()
        indicatorTask?.cancel()
        folderTasks.values.forEach { $0.cancel() }
        folderTasks = [:]
    }

    private func remember(_ loaded: [TreeEntry], sizes texts: [String: String]) {
        for entry in loaded { entries[entry.path] = entry }
        sizes.merge(texts) { _, new in new }
    }

    private nonisolated static func sizeTexts(_ loaded: [TreeEntry]) async -> [String: String] {
        await Task.detached(priority: .userInitiated) { CommitTreeOutline.sizeTexts(loaded) }.value
    }

    private func rebuildRows() {
        guard case let .loaded(top) = root else {
            if !rows.isEmpty { rows = [] }
            return
        }
        let next = CommitTreeOutline.filtered(CommitTreeOutline.rows(root: top, children: children, expanded: expanded, sizes: sizes), by: filter)
        if next != rows { rows = next }
    }
}
