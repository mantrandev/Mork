import Foundation

public protocol LoadCommitUseCaseProtocol: Sendable {
    func execute(revision: String) async throws -> Commit
}

public final class LoadCommitUseCase: LoadCommitUseCaseProtocol {
    private let search: CommitSearchRepositoryProtocol

    public init(search: CommitSearchRepositoryProtocol) {
        self.search = search
    }

    public func execute(revision: String) async throws -> Commit {
        try await search.commit(revision: revision)
    }
}
