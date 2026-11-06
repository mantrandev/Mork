import Foundation

public protocol CreateBranchUseCaseProtocol: Sendable {
    func execute(name: String) async throws
}

public final class CreateBranchUseCase: CreateBranchUseCaseProtocol {
    private let branches: BranchRepositoryProtocol

    public init(branches: BranchRepositoryProtocol) {
        self.branches = branches
    }

    public func execute(name: String) async throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw GitDomainError.emptyBranchName }
        try await branches.create(named: name)
    }
}
