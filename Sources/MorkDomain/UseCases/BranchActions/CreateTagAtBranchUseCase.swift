import Foundation

public protocol CreateTagAtBranchUseCaseProtocol: Sendable {
    func execute(name: String, message: String, branch: Branch) async throws
}

public final class CreateTagAtBranchUseCase: CreateTagAtBranchUseCaseProtocol {
    private let branches: BranchActionsRepositoryProtocol

    public init(branches: BranchActionsRepositoryProtocol) {
        self.branches = branches
    }

    public func execute(name: String, message: String, branch: Branch) async throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw GitDomainError.emptyTagName }
        try await branches.createTag(named: name, message: message.trimmingCharacters(in: .whitespacesAndNewlines), at: branch.name)
    }
}
