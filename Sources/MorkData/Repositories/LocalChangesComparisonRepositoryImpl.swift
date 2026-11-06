import MorkDomain
import Foundation

public final class LocalChangesComparisonRepositoryImpl: LocalChangesComparisonRepositoryProtocol {
    private let executor: GitCommandExecuting
    private let diffOptions: DiffOptionsProviding

    public init(executor: GitCommandExecuting, diffOptions: DiffOptionsProviding = DiffOptions.standard) {
        self.executor = executor
        self.diffOptions = diffOptions
    }

    public func changedFiles(since revision: String) async throws -> [CommitFileChange] {
        GitOutputParser.nameStatus(try await executor.read(["diff", "--name-status", "-z", "-M", revision]))
    }

    public func untrackedFiles() async throws -> [String] {
        try await executor.read(["ls-files", "--others", "--exclude-standard", "-z"])
            .split(separator: "\0", omittingEmptySubsequences: true)
            .map(String.init)
    }

    public func diff(since revision: String, file: CommitFileChange) async throws -> String {
        let paths = (file.originalPath.map { [$0] } ?? []) + [file.path]
        return try await executor.readLossless(["--literal-pathspecs", "diff", "-M"] + diffOptions.diffOptions().arguments + [revision, "--"] + paths)
    }

    public func untrackedDiff(path: String) async throws -> String {
        try await executor.readLossless(["diff"] + diffOptions.diffOptions().arguments + ["--no-index", "--", "/dev/null", path], allowedExitCodes: [0, 1])
    }
}
