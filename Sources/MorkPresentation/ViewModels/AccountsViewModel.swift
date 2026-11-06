import MorkDomain
import Foundation
import Observation

@MainActor
@Observable
public final class AccountsViewModel {
    public enum DeviceFlowState: Equatable, Sendable {
        case idle
        case requesting
        case waiting(userCode: String, verificationURL: URL)
        case failed(String)
    }

    public private(set) var entries: [AccountEntry] = []
    public var provider: AccountProvider = .github {
        didSet { if provider != oldValue { errorMessage = nil } }
    }
    public var address = ""
    public var username = ""
    public var token = ""
    public private(set) var isSigningIn = false
    public private(set) var errorMessage: String?
    public private(set) var notice: String?
    public private(set) var deviceFlow: DeviceFlowState = .idle
    public var githubClientID: String
    public var gitlabClientID: String
    public private(set) var preferences: AccountPreferences
    @ObservationIgnored public private(set) var browserSignInTask: Task<Void, Never>?
    @ObservationIgnored private var avatars: [URL: Data] = [:]

    private let dependencies: AccountsDependencies

    public init(dependencies: AccountsDependencies) {
        self.dependencies = dependencies
        let preferences = dependencies.loadPreferences.execute()
        self.preferences = preferences
        githubClientID = preferences.githubClientID
        gitlabClientID = preferences.gitlabClientID
    }

    public var lesson: String { Lessons.credentialHelpers }
    public var showsAddress: Bool { provider.acceptsCustomHost }
    public var showsUsername: Bool { provider.needsUsername }
    public var secretTitle: String { provider.secretTitle }
    public var readyAccounts: [Account] { entries.filter { $0.status == .ready }.map(\.account) }

    public var tokenPageURL: URL? {
        if provider.acceptsCustomHost, provider.defaultHost == nil, address.trimmingCharacters(in: .whitespaces).isEmpty { return nil }
        return try? AccountServer.make(provider: provider, address: address).tokenPageURL
    }

    public var canSignIn: Bool {
        !isSigningIn && !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (!showsUsername || !username.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    public var canUseBrowserSignIn: Bool {
        provider.supportsDeviceFlow && preferences.clientID(for: provider) != nil
    }

    public func load() async {
        entries = await dependencies.loadAccounts.execute()
    }

    public func signIn() async {
        guard !isSigningIn else { return }
        isSigningIn = true
        defer { isSigningIn = false }
        errorMessage = nil
        notice = nil
        let signIn = AccountSignIn(provider: provider, address: showsAddress ? address : "", username: showsUsername ? username : "", secret: token)
        do {
            let account = try await dependencies.addAccount.execute(signIn)
            token = ""
            notice = "Signed in as \(account.login) on \(account.server.displayName). The token is in your Keychain."
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func remove(_ account: Account) async {
        errorMessage = nil
        notice = nil
        do {
            try await dependencies.removeAccount.execute(account)
            notice = "Removed \(account.login) and its Keychain item."
        } catch {
            errorMessage = error.localizedDescription
        }
        await load()
    }

    public func prepareSignIn(again account: Account) {
        provider = account.provider
        address = account.provider.acceptsCustomHost ? account.server.webURL.absoluteString : ""
        username = account.provider.needsUsername ? account.apiUsername ?? account.gitUsername : ""
        token = ""
        notice = "Paste a new token for \(account.login) and sign in."
    }

    public func saveClientIDs() {
        var updated = preferences
        updated.githubClientID = githubClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.gitlabClientID = gitlabClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        githubClientID = updated.githubClientID
        gitlabClientID = updated.gitlabClientID
        dependencies.savePreferences.execute(updated)
        preferences = updated
    }

    public func updatePreferences(_ change: (inout AccountPreferences) -> Void) {
        var updated = dependencies.loadPreferences.execute()
        change(&updated)
        dependencies.savePreferences.execute(updated)
        preferences = updated
    }

    public func startBrowserSignIn() {
        browserSignInTask?.cancel()
        browserSignInTask = Task { await signInWithBrowser() }
    }

    public func cancelBrowserSignIn() {
        browserSignInTask?.cancel()
        browserSignInTask = nil
        deviceFlow = .idle
    }

    public func signInWithBrowser() async {
        errorMessage = nil
        notice = nil
        deviceFlow = .requesting
        do {
            let session = try await dependencies.requestDeviceCode.execute(provider: provider, address: showsAddress ? address : "")
            try Task.checkCancellation()
            deviceFlow = .waiting(userCode: session.authorization.userCode, verificationURL: session.authorization.verificationURL)
            let account = try await dependencies.completeDeviceFlow.execute(session)
            try Task.checkCancellation()
            deviceFlow = .idle
            notice = "Signed in as \(account.login) on \(account.server.displayName). The token is in your Keychain."
            await load()
        } catch is CancellationError {
            deviceFlow = .idle
        } catch {
            deviceFlow = Task.isCancelled ? .idle : .failed(error.localizedDescription)
        }
    }

    public func avatar(for account: Account) async -> Data? {
        guard let url = account.avatarURL else { return nil }
        if let cached = avatars[url] { return cached }
        let data = await dependencies.loadAvatar.execute(url: url)
        if let data { avatars[url] = data }
        return data
    }
}
