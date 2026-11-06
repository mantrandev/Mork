import Foundation

public protocol LoadAccountsUseCaseProtocol: Sendable {
    func execute() async -> [AccountEntry]
}

public protocol AddAccountUseCaseProtocol: Sendable {
    func execute(_ signIn: AccountSignIn) async throws -> Account
}

public protocol RemoveAccountUseCaseProtocol: Sendable {
    func execute(_ account: Account) async throws
}

public protocol LoadHostedRepositoriesUseCaseProtocol: Sendable {
    func execute(account: Account, page: URL?) async throws -> HostedRepositoryPage
}

public protocol LoadAvatarUseCaseProtocol: Sendable {
    func execute(url: URL) async -> Data?
}

public protocol LoadAccountPreferencesUseCaseProtocol: Sendable {
    func execute() -> AccountPreferences
}

public protocol SaveAccountPreferencesUseCaseProtocol: Sendable {
    func execute(_ preferences: AccountPreferences)
}

public final class LoadAccountsUseCase: LoadAccountsUseCaseProtocol {
    private let store: AccountStoreProtocol
    private let secrets: AccountSecretStoreProtocol

    public init(store: AccountStoreProtocol, secrets: AccountSecretStoreProtocol) {
        self.store = store
        self.secrets = secrets
    }

    public func execute() async -> [AccountEntry] {
        var entries: [AccountEntry] = []
        for account in store.accounts() {
            entries.append(AccountEntry(account: account, status: await secrets.hasSecret(for: account) ? .ready : .needsSignIn))
        }
        return entries
    }
}

public final class AddAccountUseCase: AddAccountUseCaseProtocol {
    private let store: AccountStoreProtocol
    private let secrets: AccountSecretStoreProtocol
    private let hosting: HostingServiceProtocol

    public init(store: AccountStoreProtocol, secrets: AccountSecretStoreProtocol, hosting: HostingServiceProtocol) {
        self.store = store
        self.secrets = secrets
        self.hosting = hosting
    }

    public func execute(_ signIn: AccountSignIn) async throws -> Account {
        let secret = signIn.secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !secret.isEmpty else { throw AccountError.emptySecret }
        let username = signIn.username.trimmingCharacters(in: .whitespacesAndNewlines)
        if signIn.provider.needsUsername, username.isEmpty { throw AccountError.emptyUsername }
        let server = try AccountServer.make(provider: signIn.provider, address: signIn.address)
        let user = try await hosting.currentUser(server: server, credential: AccountCredential(username: username, secret: secret))
        if let scopes = user.scopes {
            let missing = AccountScopes.missing(signIn.provider.requiredScopes, granted: scopes)
            guard missing.isEmpty else { throw AccountError.missingScopes(missing, signIn.provider) }
        }
        let account = Account(
            server: server,
            login: user.login,
            name: user.name,
            avatarURL: user.avatarURL,
            gitUsername: signIn.gitUsername ?? user.login,
            apiUsername: username.isEmpty ? nil : username,
            scopes: user.scopes
        )
        var accounts = store.accounts()
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            guard await !secrets.hasSecret(for: accounts[index]) else {
                throw AccountError.duplicateAccount(login: user.login, host: server.displayName)
            }
            accounts.remove(at: index)
        }
        try await secrets.setSecret(secret, for: account)
        store.save(accounts + [account])
        return account
    }
}

public final class RemoveAccountUseCase: RemoveAccountUseCaseProtocol {
    private let store: AccountStoreProtocol
    private let secrets: AccountSecretStoreProtocol

    public init(store: AccountStoreProtocol, secrets: AccountSecretStoreProtocol) {
        self.store = store
        self.secrets = secrets
    }

    public func execute(_ account: Account) async throws {
        try await secrets.deleteSecret(for: account)
        store.save(store.accounts().filter { $0.id != account.id })
    }
}

public final class LoadHostedRepositoriesUseCase: LoadHostedRepositoriesUseCaseProtocol {
    private let secrets: AccountSecretStoreProtocol
    private let hosting: HostingServiceProtocol

    public init(secrets: AccountSecretStoreProtocol, hosting: HostingServiceProtocol) {
        self.secrets = secrets
        self.hosting = hosting
    }

    public func execute(account: Account, page: URL?) async throws -> HostedRepositoryPage {
        let credential = try await AccountCredentials.load(for: account, from: secrets)
        return try await hosting.repositories(server: account.server, credential: credential, page: page)
    }
}

public final class LoadAvatarUseCase: LoadAvatarUseCaseProtocol {
    private let avatars: AvatarRepositoryProtocol

    public init(avatars: AvatarRepositoryProtocol) {
        self.avatars = avatars
    }

    public func execute(url: URL) async -> Data? {
        try? await avatars.avatar(at: url)
    }
}

public final class LoadAccountPreferencesUseCase: LoadAccountPreferencesUseCaseProtocol {
    private let store: AccountStoreProtocol

    public init(store: AccountStoreProtocol) {
        self.store = store
    }

    public func execute() -> AccountPreferences {
        store.preferences()
    }
}

public final class SaveAccountPreferencesUseCase: SaveAccountPreferencesUseCaseProtocol {
    private let store: AccountStoreProtocol

    public init(store: AccountStoreProtocol) {
        self.store = store
    }

    public func execute(_ preferences: AccountPreferences) {
        store.save(preferences)
    }
}

enum AccountCredentials {
    static func load(for account: Account, from secrets: AccountSecretStoreProtocol) async throws -> AccountCredential {
        guard let secret = try await secrets.secret(for: account) else {
            throw AccountError.needsSignIn(login: account.login, host: account.server.displayName)
        }
        return AccountCredential(username: account.apiUsername ?? account.gitUsername, secret: secret)
    }
}
