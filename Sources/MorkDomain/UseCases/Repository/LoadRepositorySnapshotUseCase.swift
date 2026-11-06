import Foundation

public protocol LoadRepositorySnapshotUseCaseProtocol: Sendable {
    func execute(historyLimit: Int, options: HistoryOptions) async throws -> RepositorySnapshot
}

extension LoadRepositorySnapshotUseCaseProtocol {
    public func execute(historyLimit: Int) async throws -> RepositorySnapshot {
        try await execute(historyLimit: historyLimit, options: .standard)
    }
}

public final class LoadRepositorySnapshotUseCase: LoadRepositorySnapshotUseCaseProtocol {
    private let workingCopy: WorkingCopyRepositoryProtocol
    private let history: HistoryRepositoryProtocol
    private let branches: BranchRepositoryProtocol
    private let stashes: StashRepositoryProtocol
    private let tags: TagRepositoryProtocol
    private let remotes: RemoteManagementRepositoryProtocol
    private let worktrees: WorktreeRepositoryProtocol
    private let submodules: SubmoduleRepositoryProtocol
    private let bisect: BisectRepositoryProtocol

    public init(
        workingCopy: WorkingCopyRepositoryProtocol,
        history: HistoryRepositoryProtocol,
        branches: BranchRepositoryProtocol,
        stashes: StashRepositoryProtocol,
        tags: TagRepositoryProtocol,
        remotes: RemoteManagementRepositoryProtocol,
        worktrees: WorktreeRepositoryProtocol,
        submodules: SubmoduleRepositoryProtocol,
        bisect: BisectRepositoryProtocol
    ) {
        self.workingCopy = workingCopy
        self.history = history
        self.branches = branches
        self.stashes = stashes
        self.tags = tags
        self.remotes = remotes
        self.worktrees = worktrees
        self.submodules = submodules
        self.bisect = bisect
    }

    public func execute(historyLimit: Int, options: HistoryOptions) async throws -> RepositorySnapshot {
        async let branchList = branches.branches()
        async let commits = history.unmarkedHistory(limit: historyLimit, options: options)
        async let changes = workingCopy.changes()
        async let stashList = stashes.stashes()
        async let tagList = tags.tags()
        async let state = workingCopy.state()
        async let remoteList = remotes.remoteList()
        async let worktreeList = worktrees.worktrees()
        async let submoduleList = submodules.submodules()
        async let bisectSession = bisect.session()
        let loadedBranches = try await branchList
        let loadedCommits = try await history.markingSyncStatus(commits, branches: loadedBranches)
        var lanes: [String?] = []
        let rows = CommitGraphLayout.layout(loadedCommits, lanes: &lanes)
        return try await RepositorySnapshot(
            branches: loadedBranches,
            changes: changes,
            history: rows,
            stashes: stashList,
            tags: tagList,
            state: state,
            remotes: remoteList,
            worktrees: worktreeList,
            submodules: submoduleList,
            bisect: bisectSession,
            historyCursor: HistoryCursor.start.advanced(over: loadedCommits, lanes: lanes, limit: historyLimit)
        )
    }
}
