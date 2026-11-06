import Foundation

public protocol AddWorktreeUseCaseProtocol: Sendable {
    func execute(path: String, checkout: WorktreeCheckout) async throws
}

public final class AddWorktreeUseCase: AddWorktreeUseCaseProtocol {
    private let worktrees: WorktreeRepositoryProtocol

    public init(worktrees: WorktreeRepositoryProtocol) {
        self.worktrees = worktrees
    }

    public func execute(path: String, checkout: WorktreeCheckout) async throws {
        let path = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { throw WorktreeError.emptyPath }
        guard path.hasPrefix("/") else { throw WorktreeError.relativePath(path) }
        try await worktrees.addWorktree(AddWorktreeRequest(path: path, checkout: try Self.normalized(checkout)))
    }

    private static func normalized(_ checkout: WorktreeCheckout) throws -> WorktreeCheckout {
        switch checkout {
        case let .newBranch(name, startPoint):
            let start = startPoint?.trimmingCharacters(in: .whitespacesAndNewlines)
            return .newBranch(try branchName(name), startPoint: start?.isEmpty == false ? start : nil)
        case let .existingBranch(name):
            return .existingBranch(try branchName(name))
        }
    }

    private static func branchName(_ name: String) throws -> String {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw WorktreeError.emptyBranchName }
        return name
    }
}
