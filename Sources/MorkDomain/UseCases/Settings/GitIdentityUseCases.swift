import Foundation

public protocol LoadGitInstallationUseCaseProtocol: Sendable {
    func execute() async throws -> GitInstallation
}

public protocol LoadGitIdentityUseCaseProtocol: Sendable {
    func execute() async throws -> GitIdentity
}

public protocol SaveGitIdentityUseCaseProtocol: Sendable {
    @discardableResult
    func execute(name: String, email: String) async throws -> GitIdentity
}

public final class LoadGitInstallationUseCase: LoadGitInstallationUseCaseProtocol {
    private let installation: GitInstallationRepositoryProtocol

    public init(installation: GitInstallationRepositoryProtocol) {
        self.installation = installation
    }

    public func execute() async throws -> GitInstallation {
        try await installation.installation()
    }
}

public final class LoadGitIdentityUseCase: LoadGitIdentityUseCaseProtocol {
    private let config: GitConfigRepositoryProtocol
    private let scope: GitConfigScope

    public init(config: GitConfigRepositoryProtocol, scope: GitConfigScope) {
        self.config = config
        self.scope = scope
    }

    public func execute() async throws -> GitIdentity {
        async let name = config.value(of: .userName, scope: scope)
        async let email = config.value(of: .userEmail, scope: scope)
        return try await GitIdentity(name: name, email: email)
    }
}

public final class SaveGitIdentityUseCase: SaveGitIdentityUseCaseProtocol {
    private let config: GitConfigRepositoryProtocol
    private let scope: GitConfigScope

    public init(config: GitConfigRepositoryProtocol, scope: GitConfigScope) {
        self.config = config
        self.scope = scope
    }

    @discardableResult
    public func execute(name: String, email: String) async throws -> GitIdentity {
        let identity = try GitIdentityRules.validated(name: name, email: email, scope: scope)
        try await write(identity.name, to: .userName)
        try await write(identity.email, to: .userEmail)
        return identity
    }

    private func write(_ value: String?, to key: GitConfigKey) async throws {
        if let value {
            try await config.setValue(value, of: key, scope: scope)
        } else {
            try await config.unsetValue(of: key, scope: scope)
        }
    }
}
