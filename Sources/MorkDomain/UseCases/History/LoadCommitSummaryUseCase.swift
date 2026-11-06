import Foundation

public protocol LoadCommitSummaryUseCaseProtocol: Sendable {
    func execute(commit: Commit) async throws -> CommitSummary
    func execute(commit: Commit, needsSignature: Bool) async throws -> CommitSummary
}

extension LoadCommitSummaryUseCaseProtocol {
    public func execute(commit: Commit, needsSignature: Bool) async throws -> CommitSummary {
        try await execute(commit: commit)
    }
}

public final class LoadCommitSummaryUseCase: LoadCommitSummaryUseCaseProtocol {
    private let history: HistoryRepositoryProtocol
    private let signatures: CommitSignatureRepositoryProtocol?

    public init(history: HistoryRepositoryProtocol, signatures: CommitSignatureRepositoryProtocol? = nil) {
        self.history = history
        self.signatures = signatures
    }

    public func execute(commit: Commit) async throws -> CommitSummary {
        try await execute(commit: commit, needsSignature: true)
    }

    public func execute(commit: Commit, needsSignature: Bool) async throws -> CommitSummary {
        async let message = history.fullMessage(of: commit)
        async let files = history.changedFiles(in: commit)
        async let signature = signatureDetails(of: commit, needed: needsSignature)
        return try await CommitSummary(commit: commit, message: message, files: files, signature: signature)
    }

    private func signatureDetails(of commit: Commit, needed: Bool) async -> CommitSignatureDetails? {
        guard needed, let signatures else { return nil }
        guard let details = try? await signatures.signatureDetails(of: commit.hash), details.status != .none else { return nil }
        return details
    }
}
