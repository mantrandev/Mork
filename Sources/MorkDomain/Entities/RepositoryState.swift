import Foundation

public enum RepositoryState: Sendable, Equatable {
    case clean
    case merging
    case rebasing
    case cherryPicking
    case reverting
}

public struct RepositorySnapshot: Sendable, Equatable {
    public let branches: [Branch]
    public let changes: [FileChange]
    public let history: [GraphRow]
    public let stashes: [Stash]
    public let tags: [Tag]
    public let state: RepositoryState
    public let remotes: [Remote]
    public let worktrees: [Worktree]
    public let submodules: [Submodule]
    public let bisect: BisectSession?
    public let historyCursor: HistoryCursor

    public init(
        branches: [Branch] = [],
        changes: [FileChange] = [],
        history: [GraphRow] = [],
        stashes: [Stash] = [],
        tags: [Tag] = [],
        state: RepositoryState = .clean,
        remotes: [Remote] = [],
        worktrees: [Worktree] = [],
        submodules: [Submodule] = [],
        bisect: BisectSession? = nil,
        historyCursor: HistoryCursor = .start
    ) {
        self.branches = branches
        self.changes = changes
        self.history = history
        self.stashes = stashes
        self.tags = tags
        self.state = state
        self.remotes = remotes
        self.worktrees = worktrees
        self.submodules = submodules
        self.bisect = bisect
        self.historyCursor = historyCursor
    }

    public static let empty = RepositorySnapshot()

    public func replacingChanges(_ changes: [FileChange]) -> RepositorySnapshot {
        RepositorySnapshot(branches: branches, changes: changes, history: history, stashes: stashes, tags: tags, state: state, remotes: remotes, worktrees: worktrees, submodules: submodules, bisect: bisect, historyCursor: historyCursor)
    }

    public var commits: [Commit] { history.map(\.commit) }
    public var currentBranch: Branch? { branches.first(where: \.isCurrent) }
    public var localBranches: [Branch] { branches.filter { !$0.isRemote } }
    public var remoteBranches: [Branch] { branches.filter(\.isRemote) }
    public var stagedChanges: [FileChange] { changes.filter(\.isStaged) }
    public var unstagedChanges: [FileChange] { changes.filter(\.hasWorktreeChanges) }
}
