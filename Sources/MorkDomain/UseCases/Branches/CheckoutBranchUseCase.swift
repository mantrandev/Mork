import Foundation

public protocol CheckoutBranchUseCaseProtocol: Sendable {
    func execute(branch: Branch) async throws
}

public final class CheckoutBranchUseCase: CheckoutBranchUseCaseProtocol {
    private let branches: BranchRepositoryProtocol

    public init(branches: BranchRepositoryProtocol) {
        self.branches = branches
    }

    public func execute(branch: Branch) async throws {
        guard !branch.isCurrent else { return }
        guard branch.isRemote else {
            try await branches.switchTo(branch)
            return
        }
        let existing = try await branches.branches().first { !$0.isRemote && $0.name == branch.localName }
        if let existing {
            try await branches.switchTo(existing)
        } else {
            try await branches.track(branch)
        }
    }
}
