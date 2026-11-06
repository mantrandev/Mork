import Foundation

public protocol RemoteManagementRepositoryProtocol: Sendable {
    func remoteList() async throws -> [Remote]
    func addRemote(named name: String, url: String) async throws
    func renameRemote(named name: String, to newName: String) async throws
    func setFetchURL(_ url: String, ofRemoteNamed name: String) async throws
    func setPushURL(_ url: String?, ofRemoteNamed name: String) async throws
    func removeRemote(named name: String) async throws
    func fetchRemote(named name: String) async throws
    func pruneRemote(named name: String) async throws
    func deleteRemoteBranch(named branch: String, onRemote remote: String) async throws
    func setUpstream(of branch: String, to upstream: String) async throws
    func unsetUpstream(of branch: String) async throws
}

public protocol WorktreeRepositoryProtocol: Sendable {
    func worktrees() async throws -> [Worktree]
    func addWorktree(_ request: AddWorktreeRequest) async throws
    func hasUncommittedChanges(atPath path: String) async throws -> Bool
    func lockWorktree(atPath path: String, reason: String) async throws
    func unlockWorktree(atPath path: String) async throws
    func removeWorktree(atPath path: String, force: Bool) async throws
    func pruneWorktrees() async throws
}

public protocol SubmoduleRepositoryProtocol: Sendable {
    func submodules() async throws -> [Submodule]
    func updateSubmodules(progress: @escaping @Sendable (String) -> Void) async throws
    func addSubmodule(url: String, path: String) async throws
    func syncSubmodules() async throws
}
