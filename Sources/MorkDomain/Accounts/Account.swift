import Foundation

public struct AccountServer: Codable, Hashable, Sendable {
    public let provider: AccountProvider
    public let host: String
    public let path: String

    public init(provider: AccountProvider, host: String, path: String = "") {
        self.provider = provider
        self.host = host.lowercased()
        self.path = path
    }

    public static func make(provider: AccountProvider, address: String) throws -> AccountServer {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard provider.acceptsCustomHost, !trimmed.isEmpty else {
            guard let host = provider.defaultHost else { throw AccountError.addressRequired(provider) }
            return AccountServer(provider: provider, host: host)
        }
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let components = URLComponents(string: candidate), let scheme = components.scheme?.lowercased() else {
            throw AccountError.invalidAddress(trimmed)
        }
        if scheme == "http" { throw AccountError.insecureAddress(trimmed) }
        guard scheme == "https", let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil, components.query == nil, components.fragment == nil else {
            throw AccountError.invalidAddress(trimmed)
        }
        var path = components.path
        while path.hasSuffix("/") { path.removeLast() }
        let authority = components.port.map { "\(host):\($0)" } ?? host
        return AccountServer(provider: provider, host: authority, path: path)
    }

    public var displayName: String { host + path }
    public var webURL: URL { URL(string: webAddress)! }
    public var apiURL: URL { provider.apiURL(host: host, path: path) }
    public var tokenPageURL: URL { provider.tokenPageURL(web: webAddress) }

    private var webAddress: String { "https://\(host)\(path)" }
}

public struct Account: Codable, Hashable, Identifiable, Sendable {
    public let server: AccountServer
    public let login: String
    public var name: String?
    public var avatarURL: URL?
    public var gitUsername: String
    public var apiUsername: String?
    public var scopes: [String]?

    public init(server: AccountServer, login: String, name: String? = nil, avatarURL: URL? = nil, gitUsername: String? = nil, apiUsername: String? = nil, scopes: [String]? = nil) {
        self.server = server
        self.login = login
        self.name = name
        self.avatarURL = avatarURL
        self.gitUsername = gitUsername ?? login
        self.apiUsername = apiUsername
        self.scopes = scopes
    }

    public var id: String { "\(server.provider.rawValue):\(server.host)\(server.path):\(login.lowercased())" }
    public var provider: AccountProvider { server.provider }
    public var displayName: String { name.flatMap { $0.isEmpty ? nil : $0 } ?? login }
}

public enum AccountStatus: Sendable, Hashable {
    case ready
    case needsSignIn
}

public struct AccountEntry: Identifiable, Hashable, Sendable {
    public let account: Account
    public let status: AccountStatus

    public init(account: Account, status: AccountStatus) {
        self.account = account
        self.status = status
    }

    public var id: String { account.id }
}

public struct AccountUser: Equatable, Sendable {
    public let login: String
    public let name: String?
    public let avatarURL: URL?
    public let scopes: [String]?

    public init(login: String, name: String?, avatarURL: URL?, scopes: [String]?) {
        self.login = login
        self.name = name
        self.avatarURL = avatarURL
        self.scopes = scopes
    }
}

public struct AccountCredential: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public let username: String
    public let secret: String

    public init(username: String, secret: String) {
        self.username = username
        self.secret = secret
    }

    public var description: String { "AccountCredential(username: \(username), secret: ***)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: ["username": username, "secret": "***"]) }
}

public struct AccountSignIn: Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public let provider: AccountProvider
    public let address: String
    public let username: String
    public let secret: String
    public let gitUsername: String?

    public init(provider: AccountProvider, address: String, username: String, secret: String, gitUsername: String? = nil) {
        self.provider = provider
        self.address = address
        self.username = username
        self.secret = secret
        self.gitUsername = gitUsername
    }

    public var description: String { "AccountSignIn(provider: \(provider.rawValue), address: \(address), username: \(username), secret: ***)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror {
        Mirror(self, children: ["provider": provider, "address": address, "username": username, "secret": "***"])
    }
}

public struct AccountPreferences: Codable, Hashable, Sendable {
    public var githubClientID: String
    public var gitlabClientID: String
    public var sshDirectory: String?

    public init(githubClientID: String = "", gitlabClientID: String = "", sshDirectory: String? = nil) {
        self.githubClientID = githubClientID
        self.gitlabClientID = gitlabClientID
        self.sshDirectory = sshDirectory
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            githubClientID: (try? container.decodeIfPresent(String.self, forKey: .githubClientID)) ?? "",
            gitlabClientID: (try? container.decodeIfPresent(String.self, forKey: .gitlabClientID)) ?? "",
            sshDirectory: (try? container.decodeIfPresent(String.self, forKey: .sshDirectory)) ?? nil
        )
    }

    public func clientID(for provider: AccountProvider) -> String? {
        let value = switch provider {
        case .github: githubClientID
        case .gitlab: gitlabClientID
        case .githubEnterprise, .bitbucket, .gitea: ""
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public struct HostedRepository: Hashable, Identifiable, Sendable {
    public let fullName: String
    public let description: String?
    public let isPrivate: Bool
    public let httpsURL: String
    public let sshURL: String

    public init(fullName: String, description: String?, isPrivate: Bool, httpsURL: String, sshURL: String) {
        self.fullName = fullName
        self.description = description
        self.isPrivate = isPrivate
        self.httpsURL = httpsURL
        self.sshURL = sshURL
    }

    public var id: String { fullName }
    public var name: String { fullName.split(separator: "/").last.map(String.init) ?? fullName }

    public func cloneURL(ssh: Bool) -> String { ssh ? sshURL : httpsURL }
}

public struct HostedRepositoryPage: Equatable, Sendable {
    public let repositories: [HostedRepository]
    public let next: URL?

    public init(repositories: [HostedRepository], next: URL?) {
        self.repositories = repositories
        self.next = next
    }
}
