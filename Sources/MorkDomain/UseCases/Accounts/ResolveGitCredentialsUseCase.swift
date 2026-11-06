import Foundation

public final class ResolveGitCredentialsUseCase: GitCredentialProviding {
    private let store: AccountStoreProtocol
    private let secrets: AccountSecretStoreProtocol

    public init(store: AccountStoreProtocol, secrets: AccountSecretStoreProtocol) {
        self.store = store
        self.secrets = secrets
    }

    public func hasAccounts() -> Bool {
        !store.accounts().isEmpty
    }

    public func plan(for remoteURLs: [String]) async -> GitCredentialPlan {
        let accounts = store.accounts()
        guard !accounts.isEmpty else { return .empty }
        var credentials: [GitHostCredential] = []
        var used: [String: Account] = [:]
        var notes: [String] = []
        var seenHosts: Set<String> = []
        for remote in remoteURLs {
            guard let endpoint = RemoteEndpoint.https(remote) else { continue }
            let key = "\(endpoint.user ?? "")@\(endpoint.host)"
            guard seenHosts.insert(key).inserted, used[endpoint.host] == nil else { continue }
            switch AccountCredentialMatcher.match(remote, in: accounts) {
            case let .none(note):
                if let note { notes.append(note) }
            case let .matched(account, note):
                if let note { notes.append(note) }
                guard let secret = try? await secrets.secret(for: account) else {
                    notes.append("The account \(account.login) on \(endpoint.host) needs sign-in: its token is missing from the Keychain, so git falls back to its own credential helper.")
                    continue
                }
                used[endpoint.host] = account
                credentials.append(GitHostCredential(host: endpoint.host, username: endpoint.user ?? account.gitUsername, secret: secret))
                notes.append("Mork answers git's password prompt for \(endpoint.host) with the \(account.provider.title) account \(account.login), through GIT_ASKPASS.")
            }
        }
        return GitCredentialPlan(credentials: credentials, accounts: used, notes: notes)
    }
}
