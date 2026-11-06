import Foundation

public protocol FetchWithOptionsUseCaseProtocol: Sendable {
    func execute(options: FetchOptions) async throws
}

public final class FetchWithOptionsUseCase: FetchWithOptionsUseCaseProtocol {
    private let remote: RemoteRepositoryProtocol

    public init(remote: RemoteRepositoryProtocol) {
        self.remote = remote
    }

    public func execute(options: FetchOptions) async throws {
        if let problem = options.problem { throw problem }
        guard try await !remote.remotes().isEmpty else { throw GitDomainError.noRemote }
        try await remote.fetch(options: options)
    }
}
