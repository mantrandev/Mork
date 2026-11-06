import MorkDomain
import Foundation

public final class WorktreeRepositoryImpl: WorktreeRepositoryProtocol {
    private let executor: GitCommandExecuting

    public init(executor: GitCommandExecuting) {
        self.executor = executor
    }

    public func worktrees() async throws -> [Worktree] {
        WorktreeListParser.parse(try await executor.read(["worktree", "list", "--porcelain", "-z"]))
    }

    public func addWorktree(_ request: AddWorktreeRequest) async throws {
        try await executor.write(request.arguments)
    }

    public func hasUncommittedChanges(atPath path: String) async throws -> Bool {
        try await !executor.read(["-C", path, "status", "--porcelain=v1"]).isEmpty
    }

    public func lockWorktree(atPath path: String, reason: String) async throws {
        try await executor.write(["worktree", "lock"] + (reason.isEmpty ? [] : ["--reason", reason]) + [path])
    }

    public func unlockWorktree(atPath path: String) async throws {
        try await executor.write(["worktree", "unlock", path])
    }

    public func removeWorktree(atPath path: String, force: Bool) async throws {
        try await executor.write(["worktree", "remove"] + (force ? ["--force"] : []) + [path])
    }

    public func pruneWorktrees() async throws {
        try await executor.write(["worktree", "prune"])
    }
}
