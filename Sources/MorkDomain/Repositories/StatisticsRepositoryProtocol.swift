import Foundation

public protocol StatisticsRepositoryProtocol: Sendable {
    func commits() async throws -> [StatisticsCommit]
    func changedFiles(commitLimit: Int) async throws -> [String]
    func referenceCounts() async throws -> ReferenceCounts
}
