import MorkDomain
import Foundation
import Observation

@MainActor
@Observable
public final class LocalChangesComparisonViewModel: Identifiable {
    public nonisolated static let loadingIndicatorDelay: Duration = .milliseconds(150)
    public nonisolated static let cachedDiffLimit = 64

    public let commit: Commit
    public private(set) var files: Loadable<LocalChangesComparison> = .idle
    public private(set) var listedFiles: [ComparedFile] = []
    public private(set) var filesRevision = 0
    public private(set) var selectedID: String?
    public private(set) var displayedFile: ComparedFile?
    public private(set) var diffError: String?
    public private(set) var showsLoadingIndicator = false
    internal private(set) var document = DiffDocument.empty

    private let dependencies: LocalChangesComparisonDependencies
    private let sleep: @Sendable (Duration) async throws -> Void
    @ObservationIgnored private var index: [String: ComparedFile] = [:]
    @ObservationIgnored private var cache: [String: DiffDocument] = [:]
    @ObservationIgnored private var cacheOrder: [String] = []
    @ObservationIgnored private var listTask: Task<Void, Never>?
    @ObservationIgnored private var diffTask: Task<Void, Never>?
    @ObservationIgnored private var indicatorTask: Task<Void, Never>?
    @ObservationIgnored private var isLoadingDiff = false

    public init(
        commit: Commit,
        dependencies: LocalChangesComparisonDependencies,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.commit = commit
        self.dependencies = dependencies
        self.sleep = sleep
    }

    public var title: String { "Compare \(commit.shortHash) to Local Changes" }
    public var command: String { "git diff --name-status -z -M \(commit.shortHash)" }

    public var lesson: String {
        [
            Lessons.explain(["diff", "--name-status", "-z", "-M", commit.shortHash]),
            "Untracked files come from git ls-files --others --exclude-standard -z and show as added."
        ].compactMap { $0 }.joined(separator: "\n\n")
    }

    public var fileCommand: String? {
        guard let file = displayedFile else { return nil }
        if file.isUntracked {
            return "git diff --no-index -- /dev/null \(ShellWords.quote(file.path))"
        }
        let paths = ([file.originalPath].compactMap { $0 } + [file.path]).map(ShellWords.quote).joined(separator: " ")
        return "git diff -M \(commit.shortHash) -- \(paths)"
    }

    public func load() {
        listTask?.cancel()
        if case .loaded = files {} else { files = .loading }
        let load = dependencies.loadComparison
        let commit = commit
        listTask = Task { [weak self] in
            let result: Loadable<LocalChangesComparison>
            var index: [String: ComparedFile] = [:]
            do {
                let comparison = try await load.execute(commit: commit)
                index = await Task.detached(priority: .userInitiated) { Self.index(comparison) }.value
                result = .loaded(comparison)
            } catch {
                result = .failed(error.localizedDescription)
            }
            guard !Task.isCancelled, let self else { return }
            self.apply(result, index: index)
        }
    }

    func apply(_ result: Loadable<LocalChangesComparison>, index: [String: ComparedFile]) {
        self.index = index
        if files != result {
            files = result
            let listed = if case let .loaded(comparison) = result { comparison.files } else { [ComparedFile]() }
            if listed != listedFiles {
                listedFiles = listed
                filesRevision += 1
            }
        }
        restoreSelection(in: result)
    }

    public func refresh() {
        cache = [:]
        cacheOrder = []
        load()
    }

    public func waitForFiles() async {
        await listTask?.value
    }

    public func waitForDiff() async {
        await diffTask?.value
    }

    public func select(_ id: String?) {
        guard id != selectedID else { return }
        selectedID = id
        showSelection()
    }

    public func close() {
        listTask?.cancel()
        diffTask?.cancel()
        indicatorTask?.cancel()
    }

    private func restoreSelection(in result: Loadable<LocalChangesComparison>) {
        guard case let .loaded(comparison) = result else {
            selectedID = nil
            showSelection()
            return
        }
        if let selectedID, index[selectedID] != nil {
            showSelection()
            return
        }
        selectedID = comparison.files.first?.id
        showSelection()
    }

    private func showSelection() {
        diffTask?.cancel()
        diffTask = nil
        guard let id = selectedID, let file = index[id] else {
            finishLoading()
            display(nil, document: .empty, error: nil)
            return
        }
        if let cached = cachedDocument(for: id) {
            finishLoading()
            display(file, document: cached, error: nil)
            return
        }
        startLoading()
        let load = dependencies.loadDiff
        let commit = commit
        diffTask = Task { [weak self] in
            let result: Result<DiffDocument, Error>
            do {
                let text = try await load.execute(commit: commit, file: file)
                result = .success(await Task.detached(priority: .userInitiated) {
                    DiffDocument(lines: DiffLine.parse(text), tabWidth: DiffMetrics.standard.tabWidth)
                }.value)
            } catch {
                result = .failure(error)
            }
            guard !Task.isCancelled, let self else { return }
            self.receive(result, for: file)
        }
    }

    func receive(_ result: Result<DiffDocument, Error>, for file: ComparedFile) {
        guard selectedID == file.id else { return }
        finishLoading()
        switch result {
        case let .success(document):
            remember(document, for: file.id)
            display(file, document: document, error: nil)
        case let .failure(error):
            display(file, document: .empty, error: error.localizedDescription)
        }
    }

    private func display(_ file: ComparedFile?, document: DiffDocument, error: String?) {
        if displayedFile != file { displayedFile = file }
        if self.document != document { self.document = document }
        if diffError != error { diffError = error }
    }

    private func cachedDocument(for id: String) -> DiffDocument? {
        guard let document = cache[id] else { return nil }
        if cacheOrder.last != id {
            cacheOrder.removeAll { $0 == id }
            cacheOrder.append(id)
        }
        return document
    }

    private func remember(_ document: DiffDocument, for id: String) {
        if cache.updateValue(document, forKey: id) != nil { cacheOrder.removeAll { $0 == id } }
        cacheOrder.append(id)
        while cacheOrder.count > Self.cachedDiffLimit {
            cache[cacheOrder.removeFirst()] = nil
        }
    }

    private func startLoading() {
        isLoadingDiff = true
        indicatorTask?.cancel()
        let sleep = sleep
        indicatorTask = Task { [weak self] in
            try? await sleep(Self.loadingIndicatorDelay)
            guard !Task.isCancelled, let self, self.isLoadingDiff else { return }
            self.showsLoadingIndicator = true
        }
    }

    private func finishLoading() {
        isLoadingDiff = false
        indicatorTask?.cancel()
        indicatorTask = nil
        if showsLoadingIndicator { showsLoadingIndicator = false }
    }

    nonisolated static func index(_ comparison: LocalChangesComparison) -> [String: ComparedFile] {
        Dictionary(comparison.files.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
