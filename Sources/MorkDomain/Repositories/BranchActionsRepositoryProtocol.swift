import Foundation

public protocol BranchActionsRepositoryProtocol: Sendable {
    func createBranch(named name: String, startPoint: String, checkout: Bool) async throws
    func createTag(named name: String, message: String, at revision: String) async throws
    func renameBranch(_ name: String, to newName: String) async throws
    func countCommits(in branch: String, missingFrom upstream: String) async throws -> Int
    func fastForwardCurrentBranch(to upstream: String) async throws
    func fastForward(branch: String, to upstream: String) async throws
    func defaultBranch(ofRemote remote: String) async throws -> String?
    func isContentMerged(_ branch: String, into target: String) async throws -> Bool
}
