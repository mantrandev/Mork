import Foundation

public protocol PushTagUseCaseProtocol: Sendable {
    func execute(name: String, remotes: [String]) async throws
}

public final class PushTagUseCase: PushTagUseCaseProtocol {
    private let remote: RemoteRepositoryProtocol

    public init(remote: RemoteRepositoryProtocol) {
        self.remote = remote
    }

    public func execute(name: String, remotes: [String]) async throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw GitDomainError.emptyTagName }
        guard !remotes.isEmpty else { throw GitDomainError.noRemote }
        for target in remotes {
            try await remote.pushTag(named: name, to: target)
        }
    }
}
