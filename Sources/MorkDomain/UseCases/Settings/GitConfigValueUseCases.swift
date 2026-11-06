import Foundation

public protocol LoadGitConfigValueUseCaseProtocol: Sendable {
    func execute() async throws -> String?
}

public protocol SaveGitConfigValueUseCaseProtocol: Sendable {
    @discardableResult
    func execute(_ value: String) async throws -> String?
}

public final class LoadGitConfigValueUseCase: LoadGitConfigValueUseCaseProtocol {
    private let config: GitConfigRepositoryProtocol
    private let key: GitConfigKey
    private let scope: GitConfigScope

    public init(config: GitConfigRepositoryProtocol, key: GitConfigKey, scope: GitConfigScope) {
        self.config = config
        self.key = key
        self.scope = scope
    }

    public func execute() async throws -> String? {
        try await config.value(of: key, scope: scope)
    }
}

public final class SaveGitConfigValueUseCase: SaveGitConfigValueUseCaseProtocol {
    private let config: GitConfigRepositoryProtocol
    private let key: GitConfigKey
    private let scope: GitConfigScope

    public init(config: GitConfigRepositoryProtocol, key: GitConfigKey, scope: GitConfigScope) {
        self.config = config
        self.key = key
        self.scope = scope
    }

    @discardableResult
    public func execute(_ value: String) async throws -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            try await config.unsetValue(of: key, scope: scope)
            return nil
        }
        try await config.setValue(trimmed, of: key, scope: scope)
        return trimmed
    }
}
