import MorkDomain
import Foundation

extension RepositoryViewModel {
    public struct SearchState: Equatable, Sendable {
        public var results: [GraphRow]?
        public var isSearching = false
        public var error: String?

        public init(results: [GraphRow]? = nil, isSearching: Bool = false, error: String? = nil) {
            self.results = results
            self.isSearching = isSearching
            self.error = error
        }

        public var matchCount: Int? { results?.count }
    }

    public struct ScrollRequest: Equatable, Sendable {
        public let id: Int
        public let hash: String
    }

    public var isSearchActive: Bool { !searchQuery.isEmpty }
    public var visibleHistory: [GraphRow] { search.results ?? historyRows }
    var visibleHistoryRows: [HistoryRowModel] { searchRows ?? historyRowModels }
    var visibleGraphLanes: Int { searchRows == nil ? historyGraphLanes : searchGraphLanes }

    public func badges(of commit: Commit) -> [String] {
        historyOptions.visibleRefs(of: commit)
    }

    public func beginSearch() {
        pane = .history
        searchFocusRequest += 1
    }

    public func clearSearch() {
        searchText = ""
    }

    public func waitForSearch() async {
        await explorationTasks.search?.value
    }

    public func setHistoryOption(_ option: WritableKeyPath<HistoryOptions, Bool>, to value: Bool) async {
        guard historyOptions[keyPath: option] != value else { return }
        historyOptions[keyPath: option] = value
        dependencies.exploration.saveHistoryOptions.execute(options: historyOptions, repository: url)
        await refresh()
    }

    public func showHead() async {
        pane = .history
        clearSearch()
        if let head = snapshot.headCommit {
            reveal(head)
            return
        }
        do {
            let loadCommit = dependencies.exploration.loadCommit
            reveal(try await reading { try await loadCommit.execute(revision: "HEAD") })
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reveal(_ commit: Commit) {
        selection = .commit(commit)
        scrollRequest = ScrollRequest(id: (scrollRequest?.id ?? 0) + 1, hash: commit.hash)
    }

    func isKnown(_ commit: Commit) -> Bool {
        let hash = commit.hash
        if presentation.historyIndex[hash] != nil { return true }
        if search.results?.contains(where: { $0.commit.hash == hash }) == true { return true }
        if case let .loaded(entries) = reflog, entries.contains(where: { $0.commit.hash == hash }) { return true }
        return false
    }

    func scheduleSearch() {
        explorationTasks.search?.cancel()
        let query = searchQuery
        guard !query.isEmpty else {
            explorationTasks.search = nil
            if search != SearchState() { search = SearchState() }
            if searchRows != nil { searchRows = nil }
            return
        }
        if !search.isSearching || search.error != nil {
            search.isSearching = true
            search.error = nil
        }
        let options = historyOptions
        let context = HistoryRowModel.Context(remoteBranches: remoteBranches, options: options, bisect: bisectSession)
        let debounce = searchDebounce
        let limit = Self.historyLimit
        let searchCommits = dependencies.exploration.searchCommits
        explorationTasks.search = Task { [weak self] in
            do {
                try await Task.sleep(for: debounce)
            } catch {
                return
            }
            let outcome: SearchState
            var rows: [HistoryRowModel]?
            do {
                let results = try await searchCommits.execute(query: query, options: options, limit: limit)
                rows = await Task.detached(priority: .userInitiated) { HistoryRowModel.make(results, context: context) }.value
                outcome = SearchState(results: results)
            } catch {
                outcome = SearchState(error: error.localizedDescription)
            }
            guard !Task.isCancelled, let self else { return }
            self.search = outcome
            self.searchRows = rows
            self.searchGraphLanes = rows?.map(\.graph.width).max() ?? 1
        }
    }

    private var searchQuery: CommitSearchQuery {
        CommitSearchQuery(mode: searchMode, text: searchText)
    }
}

final class ExplorationTasks {
    var search: Task<Void, Never>?
    var inspection: Task<Void, Never>?
    var fileDiff: Task<Void, Never>?

    deinit {
        search?.cancel()
        inspection?.cancel()
        fileDiff?.cancel()
    }
}
