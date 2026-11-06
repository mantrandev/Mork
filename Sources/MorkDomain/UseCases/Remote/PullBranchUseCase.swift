import Foundation

public protocol PullBranchUseCaseProtocol: Sendable {
    func execute(branch: Branch?) async throws
}

public final class PullBranchUseCase: PullBranchUseCaseProtocol {
    private let remote: RemoteRepositoryProtocol

    public init(remote: RemoteRepositoryProtocol) {
        self.remote = remote
    }

    public func execute(branch: Branch?) async throws {
        guard branch != nil else { throw GitDomainError.detachedHead }
        guard try await !remote.remotes().isEmpty else { throw GitDomainError.noRemote }
        try await remote.pull()
    }
}
