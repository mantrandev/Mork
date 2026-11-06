import Foundation

public protocol CheckoutCommitUseCaseProtocol: Sendable {
    func execute(commit: Commit) async throws
}

public final class CheckoutCommitUseCase: CheckoutCommitUseCaseProtocol {
    private let revisions: RevisionRepositoryProtocol

    public init(revisions: RevisionRepositoryProtocol) {
        self.revisions = revisions
    }

    public func execute(commit: Commit) async throws {
        try await revisions.checkout(commit)
    }
}
