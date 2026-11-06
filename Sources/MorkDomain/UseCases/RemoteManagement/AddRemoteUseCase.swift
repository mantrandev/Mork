import Foundation

public protocol AddRemoteUseCaseProtocol: Sendable {
    func execute(name: String, url: String, fetch: Bool) async throws
}

public final class AddRemoteUseCase: AddRemoteUseCaseProtocol {
    private let remotes: RemoteManagementRepositoryProtocol

    public init(remotes: RemoteManagementRepositoryProtocol) {
        self.remotes = remotes
    }

    public func execute(name: String, url: String, fetch: Bool) async throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = url.trimmingCharacters(in: .whitespacesAndNewlines)
        try RemoteNameRules.validate(name, existing: [])
        guard !url.isEmpty else { throw RemoteValidationError.emptyURL }
        try RemoteNameRules.validate(name, existing: try await remotes.remoteList().map(\.name))
        try await remotes.addRemote(named: name, url: url)
        if fetch { try await remotes.fetchRemote(named: name) }
    }
}
