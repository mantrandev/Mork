import MorkDomain
import Foundation

public final class FileInspectionRepositoryImpl: FileInspectionRepositoryProtocol {
    private let executor: GitCommandExecuting

    public init(executor: GitCommandExecuting) {
        self.executor = executor
    }

    public func history(of path: String, limit: Int) async throws -> [FileHistoryEntry] {
        guard try await executor.hasHead() else { return [] }
        return GitOutputParser.fileHistory(try await executor.read([
            "--literal-pathspecs", "log", "--follow", "-M", "-n", "\(limit)",
            "--pretty=format:%x1e\(GitOutputParser.historyFormat)", "--name-status", "-z", "--", path
        ]))
    }

    public func blame(of path: String, at commit: Commit?) async throws -> [BlameLine] {
        BlameParser.parse(try await executor.read(["blame", "--porcelain"] + (commit.map { [$0.hash] } ?? []) + ["--", path]))
    }
}
