import Foundation

public protocol LoadSigningSettingsUseCaseProtocol: Sendable {
    func execute() async throws -> SigningSettings
}

public protocol SaveSigningSettingsUseCaseProtocol: Sendable {
    @discardableResult
    func execute(_ settings: SigningSettings) async throws -> SigningSettings
}

public protocol LoadSigningKeysUseCaseProtocol: Sendable {
    func execute() async -> [SigningKey]
}

public final class LoadSigningSettingsUseCase: LoadSigningSettingsUseCaseProtocol {
    private let config: GitConfigRepositoryProtocol
    private let scope: GitConfigScope

    public init(config: GitConfigRepositoryProtocol, scope: GitConfigScope) {
        self.config = config
        self.scope = scope
    }

    public func execute() async throws -> SigningSettings {
        async let sign = config.value(of: .commitGpgSign, scope: scope)
        async let format = config.value(of: .gpgFormat, scope: scope)
        async let key = config.value(of: .userSigningKey, scope: scope)
        return try await SigningSettings(
            signsCommits: SigningSettings.parseBoolean(sign),
            format: format.flatMap { SigningFormat(rawValue: $0.lowercased()) },
            key: key.flatMap { $0.isEmpty ? nil : $0 }
        )
    }
}

public final class SaveSigningSettingsUseCase: SaveSigningSettingsUseCaseProtocol {
    private let config: GitConfigRepositoryProtocol
    private let scope: GitConfigScope

    public init(config: GitConfigRepositoryProtocol, scope: GitConfigScope) {
        self.config = config
        self.scope = scope
    }

    @discardableResult
    public func execute(_ settings: SigningSettings) async throws -> SigningSettings {
        let key = settings.key?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = SigningSettings(signsCommits: settings.signsCommits, format: settings.format, key: key?.isEmpty == false ? key : nil)
        try await write(normalized.signsCommits.map { $0 ? "true" : "false" }, to: .commitGpgSign)
        try await write(normalized.format?.rawValue, to: .gpgFormat)
        try await write(normalized.key, to: .userSigningKey)
        return normalized
    }

    private func write(_ value: String?, to key: GitConfigKey) async throws {
        if let value {
            try await config.setValue(value, of: key, scope: scope)
        } else {
            try await config.unsetValue(of: key, scope: scope)
        }
    }
}

public final class LoadSigningKeysUseCase: LoadSigningKeysUseCaseProtocol {
    private let keys: SigningKeyRepositoryProtocol

    public init(keys: SigningKeyRepositoryProtocol) {
        self.keys = keys
    }

    public func execute() async -> [SigningKey] {
        async let gpg = (try? keys.gpgKeys()) ?? []
        async let ssh = (try? keys.sshKeys()) ?? []
        return await gpg + ssh
    }
}
