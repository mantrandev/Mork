import Foundation

public protocol RemoveWorktreeUseCaseProtocol: Sendable {
    func execute(worktree: Worktree, force: Bool) async throws -> WorktreeRemoval
}

public final class RemoveWorktreeUseCase: RemoveWorktreeUseCaseProtocol {
    private let worktrees: WorktreeRepositoryProtocol

    public init(worktrees: WorktreeRepositoryProtocol) {
        self.worktrees = worktrees
    }

    public func execute(worktree: Worktree, force: Bool) async throws -> WorktreeRemoval {
        guard !worktree.isMain else { throw WorktreeError.cannotRemoveMain }
        guard !worktree.isLocked else { throw WorktreeError.locked(worktree.path) }
        if !force, !worktree.isPrunable, try await worktrees.hasUncommittedChanges(atPath: worktree.path) {
            return .needsForce
        }
        try await worktrees.removeWorktree(atPath: worktree.path, force: force)
        return .removed
    }
}
