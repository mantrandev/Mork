import Foundation

public protocol CreateBranchFromBranchUseCaseProtocol: Sendable {
    func execute(name: String, startPoint: Branch, checkout: Bool) async throws
}

public final class CreateBranchFromBranchUseCase: CreateBranchFromBranchUseCaseProtocol {
    private let branches: BranchActionsRepositoryProtocol

    public init(branches: BranchActionsRepositoryProtocol) {
        self.branches = branches
    }

    public func execute(name: String, startPoint: Branch, checkout: Bool) async throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        try BranchNameRules.validate(name, existing: [])
        try await branches.createBranch(named: name, startPoint: startPoint.name, checkout: checkout)
    }
}
