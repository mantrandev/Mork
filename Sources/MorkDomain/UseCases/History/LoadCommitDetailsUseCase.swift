import Foundation

public protocol LoadCommitDetailsUseCaseProtocol: Sendable {
    func execute(commit: Commit) async throws -> String
}

public final class LoadCommitDetailsUseCase: LoadCommitDetailsUseCaseProtocol {
    private let history: HistoryRepositoryProtocol

    public init(history: HistoryRepositoryProtocol) {
        self.history = history
    }

    public func execute(commit: Commit) async throws -> String {
        try await history.details(of: commit)
    }
}
