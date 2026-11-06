import Foundation

public protocol EditRemoteUseCaseProtocol: Sendable {
    func execute(remote: Remote, edit: RemoteEdit) async throws
}

public final class EditRemoteUseCase: EditRemoteUseCaseProtocol {
    private let remotes: RemoteManagementRepositoryProtocol

    public init(remotes: RemoteManagementRepositoryProtocol) {
        self.remotes = remotes
    }

    public func execute(remote: Remote, edit: RemoteEdit) async throws {
        let name = edit.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let fetchURL = edit.fetchURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let push = edit.pushURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let pushURL = push.isEmpty || push == fetchURL ? nil : push
        let renames = name != remote.name
        if renames { try RemoteNameRules.validate(name, existing: []) }
        guard !fetchURL.isEmpty else { throw RemoteValidationError.emptyURL }
        if renames {
            try RemoteNameRules.validate(name, existing: try await remotes.remoteList().map(\.name).filter { $0 != remote.name })
            try await remotes.renameRemote(named: remote.name, to: name)
        }
        if fetchURL != remote.fetchURL { try await remotes.setFetchURL(fetchURL, ofRemoteNamed: name) }
        if pushURL != remote.pushURL { try await remotes.setPushURL(pushURL, ofRemoteNamed: name) }
    }
}
