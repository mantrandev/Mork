import MorkDomain
import Foundation

public final class GitFlowRepositoryImpl: GitFlowRepositoryProtocol {
    private let executor: GitStreamingCommandExecuting

    public init(executor: GitStreamingCommandExecuting) {
        self.executor = executor
    }

    public func configuration() async throws -> [String: String] {
        GitOutputParser.configEntries(try await executor.read(["config", "--local", "--null", "--get-regexp", "^gitflow\\."], allowedExitCodes: [0, 1]))
    }

    public func localBranches() async throws -> [String] {
        GitOutputParser.lines(try await executor.read(["for-each-ref", "--format=%(refname:short)", "refs/heads"]))
    }

    public func tags() async throws -> [String] {
        GitOutputParser.lines(try await executor.read(["for-each-ref", "--format=%(refname:short)", "refs/tags"]))
    }

    public func currentBranch() async throws -> String? {
        let name = try await executor.read(["symbolic-ref", "--quiet", "--short", "HEAD"], allowedExitCodes: [0, 1]).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    public func hasCommits() async throws -> Bool {
        try await executor.hasHead()
    }

    public func run(_ step: GitFlowStep) async throws {
        _ = try await executor.run(step.arguments, environment: [:], notes: [step.note], kind: .write, allowedExitCodes: [0]) { _ in }
    }

    public func isMerging() async throws -> Bool {
        try await !executor.read(["rev-parse", "--quiet", "--verify", "MERGE_HEAD"], allowedExitCodes: [0, 1]).isEmpty
    }
}
