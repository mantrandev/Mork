import Foundation

public protocol AccountStoreProtocol: Sendable {
    func accounts() -> [Account]
    func save(_ accounts: [Account])
    func preferences() -> AccountPreferences
    func save(_ preferences: AccountPreferences)
}

public protocol AccountSecretStoreProtocol: Sendable {
    func secret(for account: Account) async throws -> String?
    func hasSecret(for account: Account) async -> Bool
    func setSecret(_ secret: String, for account: Account) async throws
    func deleteSecret(for account: Account) async throws
}

public protocol HostingServiceProtocol: Sendable {
    func currentUser(server: AccountServer, credential: AccountCredential) async throws -> AccountUser
    func repositories(server: AccountServer, credential: AccountCredential, page: URL?) async throws -> HostedRepositoryPage
    func addSSHKey(server: AccountServer, credential: AccountCredential, title: String, key: String) async throws
}

public protocol DeviceFlowServiceProtocol: Sendable {
    func requestCode(server: AccountServer, clientID: String) async throws -> DeviceAuthorization
    func pollToken(server: AccountServer, clientID: String, deviceCode: String) async throws -> DeviceTokenResponse
}

public protocol AvatarRepositoryProtocol: Sendable {
    func avatar(at url: URL) async throws -> Data
}

public protocol SSHKeyRepositoryProtocol: Sendable {
    func keys(in directory: URL) async throws -> [SSHKey]
    func fileExists(at url: URL) -> Bool
    func generateKey(_ request: SSHKeyRequest) async throws
    func publicKey(of key: SSHKey) async throws -> String
    func testConnection(_ request: SSHConnectionRequest) async throws -> SSHCommandOutput
}
