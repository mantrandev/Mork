import Foundation

public protocol RepositoryLocatorProtocol: Sendable {
    func locateRepository(containing url: URL) async throws -> URL
    func initializeRepository(at url: URL) async throws
}

public protocol WorkingCopyRepositoryProtocol: Sendable {
    func changes() async throws -> [FileChange]
    func ignoredFiles() async throws -> [FileChange]
    func diff(for change: FileChange, staged: Bool) async throws -> String
    func stage(paths: [String]) async throws
    func forceStage(paths: [String]) async throws
    func stageAll() async throws
    func unstage(paths: [String]) async throws
    func discard(_ change: FileChange) async throws
    func commit(message: String, amend: Bool) async throws
    func lastCommitMessage() async throws -> String?
    func state() async throws -> RepositoryState
    func abortMerge() async throws
    func apply(patch: String, action: HunkAction) async throws
}

public protocol HistoryRepositoryProtocol: Sendable {
    func history(limit: Int, options: HistoryOptions) async throws -> [Commit]
    func history(limit: Int, skip: Int, options: HistoryOptions) async throws -> [Commit]
    func unmarkedHistory(limit: Int, options: HistoryOptions) async throws -> [Commit]
    func markingSyncStatus(_ commits: [Commit], branches: [Branch]) async throws -> [Commit]
    func details(of commit: Commit) async throws -> String
    func fullMessage(of commit: Commit) async throws -> String
    func changedFiles(in commit: Commit) async throws -> [CommitFileChange]
    func diff(of file: CommitFileChange, in commit: Commit) async throws -> String
}

public protocol BranchRepositoryProtocol: Sendable {
    func branches() async throws -> [Branch]
    func create(named name: String) async throws
    func switchTo(_ branch: Branch) async throws
    func track(_ remoteBranch: Branch) async throws
    func delete(_ branch: Branch, force: Bool) async throws
    func merge(_ branch: Branch) async throws
}

public protocol RemoteRepositoryProtocol: Sendable {
    func remotes() async throws -> [String]
    func fetch() async throws
    func pull() async throws
    func push(_ branch: Branch, setUpstreamTo remote: String?) async throws
    func pull(mode: PullMode) async throws
    func pull(options: PullOptions) async throws
    func push(options: PushOptions) async throws
    func fetch(options: FetchOptions) async throws
    func pushTag(named name: String, to remote: String) async throws
}

public protocol StashRepositoryProtocol: Sendable {
    func stashes() async throws -> [Stash]
    func save(message: String) async throws
    func apply(_ stash: Stash, drop: Bool) async throws
    func drop(_ stash: Stash) async throws
}

public protocol TagRepositoryProtocol: Sendable {
    func tags() async throws -> [Tag]
    func create(named name: String, message: String) async throws
    func delete(_ tag: Tag) async throws
}

public protocol GitCommandRepositoryProtocol: Sendable {
    func run(arguments: [String]) async throws
}

public protocol GitCommandLogging: Sendable {
    func record(_ record: GitCommandRecord) async
}

extension HistoryRepositoryProtocol {
    public func unmarkedHistory(limit: Int, options: HistoryOptions) async throws -> [Commit] {
        try await history(limit: limit, options: options)
    }

    public func markingSyncStatus(_ commits: [Commit], branches: [Branch]) async throws -> [Commit] {
        commits
    }
}
