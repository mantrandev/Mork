import Foundation

public protocol GitFlowRepositoryProtocol: Sendable {
    func configuration() async throws -> [String: String]
    func localBranches() async throws -> [String]
    func tags() async throws -> [String]
    func currentBranch() async throws -> String?
    func hasCommits() async throws -> Bool
    func run(_ step: GitFlowStep) async throws
    func isMerging() async throws -> Bool
}
