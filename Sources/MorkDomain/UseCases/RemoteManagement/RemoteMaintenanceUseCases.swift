import Foundation

public protocol RemoveRemoteUseCaseProtocol: Sendable {
    func execute(remote: Remote) async throws
}

public protocol FetchRemoteUseCaseProtocol: Sendable {
    func execute(remote: Remote) async throws
}

public protocol PruneRemoteUseCaseProtocol: Sendable {
    func execute(remote: Remote) async throws
}

public final class RemoveRemoteUseCase: RemoveRemoteUseCaseProtocol {
    private let remotes: RemoteManagementRepositoryProtocol

    public init(remotes: RemoteManagementRepositoryProtocol) {
        self.remotes = remotes
    }

    public func execute(remote: Remote) async throws {
        try await remotes.removeRemote(named: remote.name)
    }
}

public final class FetchRemoteUseCase: FetchRemoteUseCaseProtocol {
    private let remotes: RemoteManagementRepositoryProtocol

    public init(remotes: RemoteManagementRepositoryProtocol) {
        self.remotes = remotes
    }

    public func execute(remote: Remote) async throws {
        try await remotes.fetchRemote(named: remote.name)
    }
}

public final class PruneRemoteUseCase: PruneRemoteUseCaseProtocol {
    private let remotes: RemoteManagementRepositoryProtocol

    public init(remotes: RemoteManagementRepositoryProtocol) {
        self.remotes = remotes
    }

    public func execute(remote: Remote) async throws {
        try await remotes.pruneRemote(named: remote.name)
    }
}
