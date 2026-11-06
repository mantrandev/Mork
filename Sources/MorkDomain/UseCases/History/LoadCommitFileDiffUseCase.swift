import Foundation

public protocol LoadCommitFileDiffUseCaseProtocol: Sendable {
    func execute(commit: Commit, file: CommitFileChange) async throws -> String
}

public final class LoadCommitFileDiffUseCase: LoadCommitFileDiffUseCaseProtocol {
    private let history: HistoryRepositoryProtocol

    public init(history: HistoryRepositoryProtocol) {
        self.history = history
    }

    public func execute(commit: Commit, file: CommitFileChange) async throws -> String {
        try await history.diff(of: file, in: commit)
    }
}
