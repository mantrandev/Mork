import Foundation

public protocol SettingsRepositoryProtocol: Sendable {
    func load() -> AppSettings?
    func save(_ settings: AppSettings)
}

public protocol DiffOptionsProviding: Sendable {
    func diffOptions() -> DiffOptions
}

public protocol GitConfigRepositoryProtocol: Sendable {
    func value(of key: GitConfigKey, scope: GitConfigScope) async throws -> String?
    func setValue(_ value: String, of key: GitConfigKey, scope: GitConfigScope) async throws
    func unsetValue(of key: GitConfigKey, scope: GitConfigScope) async throws
}

public protocol GitInstallationRepositoryProtocol: Sendable {
    func installation() async throws -> GitInstallation
}

public protocol CommandLineToolRepositoryProtocol: Sendable {
    func status() -> CommandLineToolStatus
    func install() throws -> CommandLineToolStatus
}
