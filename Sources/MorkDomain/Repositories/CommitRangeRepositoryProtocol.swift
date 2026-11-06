import Foundation

public protocol CommitRangeRepositoryProtocol: Sendable {
    func isAncestor(_ ancestor: Commit, of descendant: Commit) async throws -> Bool
    func changedFiles(in range: CommitRange) async throws -> [CommitFileChange]
    func diff(in range: CommitRange, file: CommitFileChange) async throws -> String
    func formatPatches(of range: CommitRange, into folder: URL) async throws -> [String]
}
