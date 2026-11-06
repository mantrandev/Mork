import Foundation

public protocol FetchRemotesUseCaseProtocol: Sendable {
    func execute() async throws
}

public final class FetchRemotesUseCase: FetchRemotesUseCaseProtocol {
    private let remote: RemoteRepositoryProtocol

    public init(remote: RemoteRepositoryProtocol) {
        self.remote = remote
    }

    public func execute() async throws {
        guard try await !remote.remotes().isEmpty else { throw GitDomainError.noRemote }
        try await remote.fetch()
    }
}
