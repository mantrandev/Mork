import MorkDomain
import Foundation

public final class StatisticsRepositoryImpl: StatisticsRepositoryProtocol {
    private static let scope = ["--exclude=refs/stash", "--all"]

    private let executor: GitCommandExecuting

    public init(executor: GitCommandExecuting) {
        self.executor = executor
    }

    public func commits() async throws -> [StatisticsCommit] {
        GitOutputParser.statisticsCommits(try await executor.read(
            ["log"] + Self.scope + ["--date=raw", "--format=\(GitOutputParser.statisticsFormat)"]
        ))
    }

    public func changedFiles(commitLimit: Int) async throws -> [String] {
        GitOutputParser.changedPaths(try await executor.read(
            ["log"] + Self.scope + ["-n", "\(commitLimit)", "--format=", "--name-only", "--no-renames", "-z"]
        ))
    }

    public func referenceCounts() async throws -> ReferenceCounts {
        GitOutputParser.referenceCounts(try await executor.read(["for-each-ref", "--format=%(refname)", "refs/heads", "refs/tags"]))
    }
}
