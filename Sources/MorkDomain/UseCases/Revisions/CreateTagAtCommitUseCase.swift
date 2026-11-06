import Foundation

public protocol CreateTagAtCommitUseCaseProtocol: Sendable {
    func execute(name: String, message: String, commit: Commit) async throws
}

public final class CreateTagAtCommitUseCase: CreateTagAtCommitUseCaseProtocol {
    private let revisions: RevisionRepositoryProtocol

    public init(revisions: RevisionRepositoryProtocol) {
        self.revisions = revisions
    }

    public func execute(name: String, message: String, commit: Commit) async throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw GitDomainError.emptyTagName }
        try await revisions.createTag(named: name, message: message.trimmingCharacters(in: .whitespacesAndNewlines), at: commit)
    }
}
