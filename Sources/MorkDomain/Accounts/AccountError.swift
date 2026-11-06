import Foundation

public enum AccountError: LocalizedError, Equatable, Sendable {
    case addressRequired(AccountProvider)
    case invalidAddress(String)
    case insecureAddress(String)
    case emptySecret
    case emptyUsername
    case invalidToken(AccountProvider)
    case missingScopes([String], AccountProvider)
    case forbidden(String)
    case rateLimited(resetAt: Date?)
    case duplicateAccount(login: String, host: String)
    case needsSignIn(login: String, host: String)
    case keychain(status: Int32)
    case network(String)
    case unexpectedResponse(status: Int)
    case deviceFlowUnavailable(AccountProvider)
    case deviceAccessDenied
    case deviceCodeExpired
    case sshKeyAlreadyAdded
    case gitAuthenticationFailed(host: String, login: String?)

    public var errorDescription: String? {
        switch self {
        case let .addressRequired(provider):
            "Enter the address of your \(provider.title) server, for example https://git.example.com."
        case let .invalidAddress(address):
            "\(address) is not a valid server address. Use the address you open in the browser, for example https://git.example.com."
        case let .insecureAddress(address):
            "\(address) uses plain http. Mork sends tokens only over https."
        case .emptySecret:
            "Paste a token first."
        case .emptyUsername:
            "Enter your Atlassian account email for an API token, or your Bitbucket username for an app password."
        case let .invalidToken(provider):
            "\(provider.title) rejected the token (401). It may be mistyped, expired or revoked. Create a new one and try again."
        case let .missingScopes(scopes, provider):
            "The token works but lacks these \(provider.title) scopes: \(scopes.joined(separator: ", ")). Create a token with them."
        case let .forbidden(message):
            "The server refused the request (403). \(message)"
        case let .rateLimited(resetAt):
            "The API rate limit is used up. Try again \(Self.when(resetAt))."
        case let .duplicateAccount(login, host):
            "\(login) on \(host) is already signed in."
        case let .needsSignIn(login, host):
            "The token of \(login) on \(host) is missing from the Keychain. Sign in again in Settings ▸ Accounts."
        case let .keychain(status):
            "The Keychain refused the operation (OSStatus \(status))."
        case let .network(message):
            "Cannot reach the server: \(message)"
        case let .unexpectedResponse(status):
            "The server answered with an unexpected status \(status)."
        case let .deviceFlowUnavailable(provider):
            "Sign in with browser needs an OAuth client ID for \(provider.title). Paste one under Settings ▸ Accounts, or sign in with a token."
        case .deviceAccessDenied:
            "The sign-in was denied in the browser."
        case .deviceCodeExpired:
            "The sign-in code expired. Start again."
        case .sshKeyAlreadyAdded:
            "This key is already added to an account on that server."
        case let .gitAuthenticationFailed(host, login):
            if let login {
                "\(host) rejected the token of \(login). It may be expired, revoked or missing the repo scope. Sign in again in Settings ▸ Accounts."
            } else {
                "\(host) asked for a username and password, and Mork cannot show a password prompt. Add an account for \(host) in Settings ▸ Accounts, or use an SSH remote."
            }
        }
    }

    private static func when(_ date: Date?) -> String {
        guard let date else { return "in a few minutes" }
        let minutes = max(1, Int((date.timeIntervalSinceNow / 60).rounded(.up)))
        let time = date.formatted(date: .omitted, time: .shortened)
        return "at \(time) (in about \(minutes) minute\(minutes == 1 ? "" : "s"))"
    }
}

public enum GitAuthenticationFailure {
    private static let markers = [
        "Authentication failed",
        "Invalid username or password",
        "HTTP Basic: Access denied",
        "could not read Username",
        "could not read Password",
        "returned error: 401",
        "returned error: 403"
    ]

    public static func matches(_ message: String) -> Bool {
        markers.contains(where: message.contains)
    }
}
