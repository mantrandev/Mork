import Foundation

public protocol CreateBranchAtCommitUseCaseProtocol: Sendable {
    func execute(name: String, commit: Commit, checkout: Bool) async throws
}

public final class CreateBranchAtCommitUseCase: CreateBranchAtCommitUseCaseProtocol {
    private let revisions: RevisionRepositoryProtocol

    public init(revisions: RevisionRepositoryProtocol) {
        self.revisions = revisions
    }

    public func execute(name: String, commit: Commit, checkout: Bool) async throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw GitDomainError.emptyBranchName }
        try await revisions.createBranch(named: name, at: commit, checkout: checkout)
    }
}
