import MorkDomain
import Foundation
import Observation

@MainActor
@Observable
public final class CommitRangeChangesViewModel {
    public nonisolated static let cachedListLimit = 16
    public nonisolated static let cachedDiffLimit = 64

    private struct Listing {
        let files: [ComparedFile]
        let index: [String: ComparedFile]
    }

    public private(set) var range: CommitRange?
    public private(set) var files: Loadable<[ComparedFile]> = .idle
    public private(set) var listedFiles: [ComparedFile] = []
    public private(set) var filesRevision = 0
    public private(set) var selectedID: String?
    public private(set) var displayedFile: ComparedFile?
    public private(set) var diffError: String?
    internal private(set) var document = DiffDocument.empty

    private let loadChanges: LoadCommitRangeChangesUseCaseProtocol
    private let loadDiff: LoadCommitRangeDiffUseCaseProtocol
    @ObservationIgnored private var index: [String: ComparedFile] = [:]
    @ObservationIgnored private var listings: [String: Listing] = [:]
    @ObservationIgnored private var listingOrder: [String] = []
    @ObservationIgnored private var diffs: [String: DiffDocument] = [:]
    @ObservationIgnored private var diffOrder: [String] = []
    @ObservationIgnored private var listTask: Task<Void, Never>?
    @ObservationIgnored private var diffTask: Task<Void, Never>?

    public init(loadChanges: LoadCommitRangeChangesUseCaseProtocol, loadDiff: LoadCommitRangeDiffUseCaseProtocol) {
        self.loadChanges = loadChanges
        self.loadDiff = loadDiff
    }

    public var fileCommand: String? {
        guard let range, let file = displayedFile else { return nil }
        let paths = ([file.originalPath].compactMap { $0 } + [file.path]).map(ShellWords.quote).joined(separator: " ")
        return "git diff -M \(range.base(abbreviated: true)) \(range.head(abbreviated: true)) -- \(paths)"
    }

    public func show(_ range: CommitRange) {
        guard range != self.range else { return }
        self.range = range
        listTask?.cancel()
        if let listing = cachedListing(for: range.id) {
            listTask = nil
            apply(.loaded(listing.files), index: listing.index)
            return
        }
        if case .loaded = files {} else { files = .loading }
        let load = loadChanges
        listTask = Task { [weak self] in
            var listing: Listing?
            let result: Loadable<[ComparedFile]>
            do {
                let files = try await load.execute(range: range)
                listing = await Task.detached(priority: .userInitiated) {
                    Listing(files: files, index: Dictionary(files.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }))
                }.value
                result = .loaded(files)
            } catch {
                result = .failed(error.localizedDescription)
            }
            guard !Task.isCancelled, let self, self.range == range else { return }
            if let listing { self.remember(listing, for: range.id) }
            self.apply(result, index: listing?.index ?? [:])
        }
    }

    public func select(_ id: String?) {
        guard id != selectedID else { return }
        selectedID = id
        showSelection()
    }

    public func releaseMemory() {
        listings = [:]
        listingOrder = []
        diffs = [:]
        diffOrder = []
    }

    public func waitForFiles() async {
        await listTask?.value
    }

    public func waitForDiff() async {
        await diffTask?.value
    }

    private func apply(_ result: Loadable<[ComparedFile]>, index: [String: ComparedFile]) {
        self.index = index
        if files != result { files = result }
        let listed = if case let .loaded(files) = result { files } else { [ComparedFile]() }
        if listed != listedFiles {
            listedFiles = listed
            filesRevision += 1
        }
        if selectedID.flatMap({ index[$0] }) == nil { selectedID = listed.first?.id }
        showSelection()
    }

    private func showSelection() {
        diffTask?.cancel()
        diffTask = nil
        guard let range, let id = selectedID, let file = index[id] else {
            display(nil, document: .empty, error: nil)
            return
        }
        let key = "\(range.id) \(id)"
        if let cached = cachedDiff(for: key) {
            display(file, document: cached, error: nil)
            return
        }
        let load = loadDiff
        diffTask = Task { [weak self] in
            let result: Result<DiffDocument, Error>
            do {
                let text = try await load.execute(range: range, file: file)
                result = .success(await Task.detached(priority: .userInitiated) {
                    DiffDocument(lines: DiffLine.parse(text), tabWidth: DiffMetrics.standard.tabWidth)
                }.value)
            } catch {
                result = .failure(error)
            }
            guard !Task.isCancelled, let self, self.range == range, self.selectedID == id else { return }
            switch result {
            case let .success(document):
                self.remember(document, for: key)
                self.display(file, document: document, error: nil)
            case let .failure(error):
                self.display(file, document: .empty, error: error.localizedDescription)
            }
        }
    }

    private func display(_ file: ComparedFile?, document: DiffDocument, error: String?) {
        if displayedFile != file { displayedFile = file }
        if self.document != document { self.document = document }
        if diffError != error { diffError = error }
    }

    private func cachedListing(for key: String) -> Listing? {
        guard let listing = listings[key] else { return nil }
        touch(key, in: &listingOrder)
        return listing
    }

    private func remember(_ listing: Listing, for key: String) {
        listings[key] = listing
        touch(key, in: &listingOrder)
        while listingOrder.count > Self.cachedListLimit { listings[listingOrder.removeFirst()] = nil }
    }

    private func cachedDiff(for key: String) -> DiffDocument? {
        guard let document = diffs[key] else { return nil }
        touch(key, in: &diffOrder)
        return document
    }

    private func remember(_ document: DiffDocument, for key: String) {
        diffs[key] = document
        touch(key, in: &diffOrder)
        while diffOrder.count > Self.cachedDiffLimit { diffs[diffOrder.removeFirst()] = nil }
    }

    private func touch(_ key: String, in order: inout [String]) {
        guard order.last != key else { return }
        order.removeAll { $0 == key }
        order.append(key)
    }
}
