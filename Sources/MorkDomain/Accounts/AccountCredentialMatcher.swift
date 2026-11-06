import Foundation

public struct RemoteEndpoint: Equatable, Sendable {
    public let user: String?
    public let host: String
    public let path: String

    public init(user: String?, host: String, path: String) {
        self.user = user
        self.host = host
        self.path = path
    }

    public static func https(_ remote: String) -> RemoteEndpoint? {
        guard let components = URLComponents(string: remote.trimmingCharacters(in: .whitespaces)),
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(), !host.isEmpty,
              components.password == nil else { return nil }
        let authority = components.port.map { "\(host):\($0)" } ?? host
        return RemoteEndpoint(user: components.user, host: authority, path: components.path)
    }
}

public enum CredentialMatch: Equatable, Sendable {
    case matched(Account, note: String?)
    case none(note: String?)
}

public enum AccountCredentialMatcher {
    public static func match(_ remote: String, in accounts: [Account]) -> CredentialMatch {
        guard let endpoint = RemoteEndpoint.https(remote) else { return .none(note: nil) }
        let onHost = accounts.filter { $0.server.host == endpoint.host }
        guard !onHost.isEmpty else { return .none(note: nil) }
        let byPath = onHost.filter { !$0.server.path.isEmpty && Self.path(endpoint.path, isInside: $0.server.path) }
        let candidates = byPath.isEmpty ? onHost.filter { $0.server.path.isEmpty } : byPath
        if let user = endpoint.user {
            let wanted = user.lowercased()
            if let account = candidates.first(where: { $0.login.lowercased() == wanted || $0.gitUsername.lowercased() == wanted }) {
                return .matched(account, note: nil)
            }
            return .none(note: "The remote URL names the user \(user), and no account on \(endpoint.host) has that login, so Mork leaves the credentials to git.")
        }
        guard let first = candidates.first else { return .none(note: nil) }
        guard candidates.count > 1 else { return .matched(first, note: nil) }
        let others = candidates.dropFirst().map { "https://\($0.login)@\(endpoint.host)/" }.joined(separator: " or ")
        return .matched(first, note: "\(candidates.count) accounts are signed in on \(endpoint.host); Mork used the first one, \(first.login). To pick another, put its login in the remote URL: \(others)…")
    }

    private static func path(_ path: String, isInside prefix: String) -> Bool {
        path == prefix || path.hasPrefix(prefix + "/")
    }
}

public struct GitHostCredential: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public let host: String
    public let username: String
    public let secret: String

    public init(host: String, username: String, secret: String) {
        self.host = host
        self.username = username
        self.secret = secret
    }

    public var description: String { "GitHostCredential(host: \(host), username: \(username), secret: ***)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: ["host": host, "username": username, "secret": "***"]) }
}

public struct GitCredentialPlan: Equatable, Sendable {
    public let credentials: [GitHostCredential]
    public let accounts: [String: Account]
    public let notes: [String]

    public init(credentials: [GitHostCredential], accounts: [String: Account] = [:], notes: [String]) {
        self.credentials = credentials
        self.accounts = accounts
        self.notes = notes
    }

    public static let empty = GitCredentialPlan(credentials: [], notes: [])

    public var isEmpty: Bool { credentials.isEmpty && notes.isEmpty }
}

public protocol GitCredentialProviding: Sendable {
    func hasAccounts() -> Bool
    func plan(for remoteURLs: [String]) async -> GitCredentialPlan
}
