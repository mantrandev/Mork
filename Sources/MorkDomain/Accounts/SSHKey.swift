import Foundation

public struct SSHKey: Hashable, Identifiable, Sendable {
    public let publicKeyURL: URL
    public let type: String
    public let bits: Int?
    public let fingerprint: String
    public let comment: String
    public let hasPrivateKey: Bool

    public init(publicKeyURL: URL, type: String, bits: Int?, fingerprint: String, comment: String, hasPrivateKey: Bool) {
        self.publicKeyURL = publicKeyURL
        self.type = type
        self.bits = bits
        self.fingerprint = fingerprint
        self.comment = comment
        self.hasPrivateKey = hasPrivateKey
    }

    public var id: String { publicKeyURL.path }
    public var name: String { publicKeyURL.deletingPathExtension().lastPathComponent }
    public var privateKeyURL: URL { publicKeyURL.deletingPathExtension() }
}

public struct SSHKeyRequest: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public let directory: URL
    public let name: String
    public let email: String
    public let passphrase: String

    public init(directory: URL, name: String, email: String, passphrase: String) {
        self.directory = directory
        self.name = name
        self.email = email
        self.passphrase = passphrase
    }

    public var privateKeyURL: URL { directory.appendingPathComponent(name) }
    public var publicKeyURL: URL { privateKeyURL.appendingPathExtension("pub") }

    public var description: String { "SSHKeyRequest(directory: \(directory.path), name: \(name), email: \(email), passphrase: \(passphrase.isEmpty ? "none" : "***"))" }
    public var debugDescription: String { description }
    public var customMirror: Mirror {
        Mirror(self, children: ["directory": directory, "name": name, "email": email, "passphrase": passphrase.isEmpty ? "none" : "***"])
    }
}

public struct SSHConnectionRequest: Equatable, Sendable {
    public let host: String
    public let identity: URL?

    public init(host: String, identity: URL?) {
        self.host = host
        self.identity = identity
    }
}

public struct SSHCommandOutput: Equatable, Sendable {
    public let exitCode: Int32
    public let output: String

    public init(exitCode: Int32, output: String) {
        self.exitCode = exitCode
        self.output = output
    }
}

public struct SSHConnectionResult: Equatable, Sendable {
    public let succeeded: Bool
    public let message: String

    public init(succeeded: Bool, message: String) {
        self.succeeded = succeeded
        self.message = message
    }
}

public enum SSHKeyError: LocalizedError, Equatable, Sendable {
    case emptyName
    case invalidName(String)
    case emptyComment
    case passphraseTooShort
    case alreadyExists(path: String)
    case invalidHost
    case uploadUnsupported(AccountProvider)
    case commandFailed(String)

    public var errorDescription: String? {
        switch self {
        case .emptyName:
            "Enter a file name for the key, for example id_ed25519."
        case let .invalidName(name):
            "\(name) cannot be used as a key file name. Use letters, digits, - and _ only, without a folder or .pub."
        case .emptyComment:
            "Enter an email. It is stored as the key's comment so you can recognise the key on the server."
        case .passphraseTooShort:
            "A passphrase needs at least 5 characters, or leave it empty."
        case let .alreadyExists(path):
            "\(path) already exists. Mork never overwrites a key: choose another name."
        case .invalidHost:
            "Enter a host name such as github.com."
        case let .uploadUnsupported(provider):
            "Mork cannot add keys to \(provider.title) yet. Copy the public key and paste it in the website's SSH keys page."
        case let .commandFailed(message):
            message
        }
    }
}
