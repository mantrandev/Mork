import Foundation

public protocol LocalChangesComparisonRepositoryProtocol: Sendable {
    func changedFiles(since revision: String) async throws -> [CommitFileChange]
    func untrackedFiles() async throws -> [String]
    func diff(since revision: String, file: CommitFileChange) async throws -> String
    func untrackedDiff(path: String) async throws -> String
}
