import MorkDomain
import Foundation

public final class CommitRangeRepositoryImpl: CommitRangeRepositoryProtocol {
    private static let notAncestorExitCode: Int32 = 1

    private let executor: GitCommandExecuting
    private let diffOptions: DiffOptionsProviding

    public init(executor: GitCommandExecuting, diffOptions: DiffOptionsProviding = DiffOptions.standard) {
        self.executor = executor
        self.diffOptions = diffOptions
    }

    public func isAncestor(_ ancestor: Commit, of descendant: Commit) async throws -> Bool {
        do {
            try await executor.read(["merge-base", "--is-ancestor", ancestor.hash, descendant.hash])
            return true
        } catch let GitDomainError.commandFailed(_, exitCode, _) where exitCode == Self.notAncestorExitCode {
            return false
        }
    }

    public func changedFiles(in range: CommitRange) async throws -> [CommitFileChange] {
        GitOutputParser.nameStatus(try await executor.read(["diff", "--name-status", "-z", "-M", range.base(), range.head()]))
    }

    public func diff(in range: CommitRange, file: CommitFileChange) async throws -> String {
        let paths = (file.originalPath.map { [$0] } ?? []) + [file.path]
        return try await executor.readLossless(["--literal-pathspecs", "diff", "-M"] + diffOptions.diffOptions().arguments + [range.base(), range.head(), "--"] + paths)
    }

    public func formatPatches(of range: CommitRange, into folder: URL) async throws -> [String] {
        GitOutputParser.lines(try await executor.write(range.patchArguments(folder: folder.path)))
    }
}
