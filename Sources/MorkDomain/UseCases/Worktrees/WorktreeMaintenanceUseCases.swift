import Foundation

public protocol LockWorktreeUseCaseProtocol: Sendable {
    func execute(worktree: Worktree, reason: String) async throws
}

public protocol UnlockWorktreeUseCaseProtocol: Sendable {
    func execute(worktree: Worktree) async throws
}

public protocol PruneWorktreesUseCaseProtocol: Sendable {
    func execute() async throws
}

public final class LockWorktreeUseCase: LockWorktreeUseCaseProtocol {
    private let worktrees: WorktreeRepositoryProtocol

    public init(worktrees: WorktreeRepositoryProtocol) {
        self.worktrees = worktrees
    }

    public func execute(worktree: Worktree, reason: String) async throws {
        guard !worktree.isMain else { throw WorktreeError.cannotLockMain }
        guard !worktree.isLocked else { return }
        try await worktrees.lockWorktree(atPath: worktree.path, reason: reason.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

public final class UnlockWorktreeUseCase: UnlockWorktreeUseCaseProtocol {
    private let worktrees: WorktreeRepositoryProtocol

    public init(worktrees: WorktreeRepositoryProtocol) {
        self.worktrees = worktrees
    }

    public func execute(worktree: Worktree) async throws {
        guard worktree.isLocked else { return }
        try await worktrees.unlockWorktree(atPath: worktree.path)
    }
}

public final class PruneWorktreesUseCase: PruneWorktreesUseCaseProtocol {
    private let worktrees: WorktreeRepositoryProtocol

    public init(worktrees: WorktreeRepositoryProtocol) {
        self.worktrees = worktrees
    }

    public func execute() async throws {
        try await worktrees.pruneWorktrees()
    }
}
