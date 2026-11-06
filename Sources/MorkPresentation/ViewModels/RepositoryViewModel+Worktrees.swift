import MorkDomain
import Foundation

extension RepositoryViewModel {
    public var worktreeRows: [WorktreeRow] {
        worktrees.map { WorktreeRow(worktree: $0, isCurrent: $0.isLocated(at: url)) }
    }

    public func makeWorktreeForm() -> WorktreeForm {
        WorktreeForm(repository: url, branches: branches, worktrees: worktrees)
    }

    public func url(of worktree: Worktree) -> URL {
        URL(fileURLWithPath: worktree.path)
    }

    @discardableResult
    public func addWorktree(path: String, checkout: WorktreeCheckout) async -> Bool {
        await perform { try await $0.workspace.worktrees.addWorktree.execute(path: path, checkout: checkout) }
    }

    public func removeWorktree(_ worktree: Worktree, force: Bool) async -> WorktreeRemoval? {
        var result: WorktreeRemoval?
        await perform { result = try await $0.workspace.worktrees.removeWorktree.execute(worktree: worktree, force: force) }
        return result
    }

    public func lockWorktree(_ worktree: Worktree, reason: String) async {
        await perform { try await $0.workspace.worktrees.lockWorktree.execute(worktree: worktree, reason: reason) }
    }

    public func unlockWorktree(_ worktree: Worktree) async {
        await perform { try await $0.workspace.worktrees.unlockWorktree.execute(worktree: worktree) }
    }

    public func pruneWorktrees() async {
        await perform { try await $0.workspace.worktrees.pruneWorktrees.execute() }
    }
}
