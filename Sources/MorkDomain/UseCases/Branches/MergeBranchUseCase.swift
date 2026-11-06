import Foundation

public protocol MergeBranchUseCaseProtocol: Sendable {
    func execute(branch: Branch) async throws
}

public final class MergeBranchUseCase: MergeBranchUseCaseProtocol {
    private let branches: BranchRepositoryProtocol

    public init(branches: BranchRepositoryProtocol) {
        self.branches = branches
    }

    public func execute(branch: Branch) async throws {
        guard !branch.isCurrent else { return }
        try await branches.merge(branch)
    }
}
