import Foundation

public protocol RevisionRepositoryProtocol: Sendable {
    func checkout(_ commit: Commit) async throws
    func createBranch(named name: String, at commit: Commit, checkout: Bool) async throws
    func createTag(named name: String, message: String, at commit: Commit) async throws
    func cherryPick(_ commit: Commit, mainline: Int?, options: CherryPickOptions) async throws
    func revert(_ commit: Commit, mainline: Int?, options: RevertOptions) async throws
    func cherryPick(_ commits: [Commit], mainline: Int?, options: CherryPickOptions) async throws
    func revert(_ commits: [Commit], mainline: Int?, options: RevertOptions) async throws
    func reset(to commit: Commit, mode: ResetMode) async throws
    func continueOperation(_ operation: RevisionOperation) async throws
    func abortOperation(_ operation: RevisionOperation) async throws
}
