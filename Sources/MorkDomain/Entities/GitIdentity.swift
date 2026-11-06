import Foundation

public enum GitConfigScope: String, Sendable {
    case global
    case local

    public var flag: String { "--\(rawValue)" }
}

public enum GitConfigKey: String, CaseIterable, Sendable {
    case userName = "user.name"
    case userEmail = "user.email"
    case commitTemplate = "commit.template"
    case commitGpgSign = "commit.gpgsign"
    case gpgFormat = "gpg.format"
    case userSigningKey = "user.signingkey"
}

public struct GitIdentity: Hashable, Sendable {
    public var name: String?
    public var email: String?

    public init(name: String?, email: String?) {
        self.name = name
        self.email = email
    }

    public static let empty = GitIdentity(name: nil, email: nil)
}

public struct GitInstallation: Hashable, Sendable {
    private static let versionPrefix = "git version "

    public let path: String?
    public let version: String

    public init(path: String?, version: String) {
        self.path = path
        self.version = version
    }

    public init(path: String?, versionOutput: String) {
        let trimmed = versionOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        self.init(path: path, version: trimmed.hasPrefix(Self.versionPrefix) ? String(trimmed.dropFirst(Self.versionPrefix.count)) : trimmed)
    }
}

public enum GitIdentityError: LocalizedError, Equatable, Sendable {
    case emptyName
    case invalidName
    case emptyEmail
    case invalidEmail(String)

    public var errorDescription: String? {
        switch self {
        case .emptyName: "Enter a name. Git writes it into every commit you make."
        case .invalidName: "A name cannot contain <, > or line breaks, because Git stores it as \"Name <email>\" in each commit."
        case .emptyEmail: "Enter an email. Git writes it into every commit you make."
        case let .invalidEmail(email): "\"\(email)\" does not look like an email: it needs one @ with text on both sides and no spaces, < or >."
        }
    }
}
