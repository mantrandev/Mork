import Foundation

public enum SigningFormat: String, CaseIterable, Identifiable, Sendable {
    case openpgp
    case ssh

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .openpgp: "OpenPGP (gpg)"
        case .ssh: "SSH"
        }
    }
}

public struct SigningSettings: Equatable, Sendable {
    public var signsCommits: Bool?
    public var format: SigningFormat?
    public var key: String?

    public init(signsCommits: Bool? = nil, format: SigningFormat? = nil, key: String? = nil) {
        self.signsCommits = signsCommits
        self.format = format
        self.key = key
    }

    public static let empty = SigningSettings()

    public static func parseBoolean(_ value: String?) -> Bool? {
        guard let value = value?.trimmingCharacters(in: .whitespaces).lowercased(), !value.isEmpty else { return nil }
        switch value {
        case "true", "yes", "on", "1": return true
        case "false", "no", "off", "0": return false
        default: return nil
        }
    }

    public func resolved(over global: SigningSettings) -> SigningSettings {
        SigningSettings(signsCommits: signsCommits ?? global.signsCommits, format: format ?? global.format, key: key ?? global.key)
    }
}

public struct SigningKey: Identifiable, Hashable, Sendable {
    public let format: SigningFormat
    public let value: String
    public let title: String
    public let detail: String

    public init(format: SigningFormat, value: String, title: String, detail: String) {
        self.format = format
        self.value = value
        self.title = title
        self.detail = detail
    }

    public var id: String { "\(format.rawValue):\(value)" }
}

public enum CommitSignature: String, Sendable, Hashable {
    case good
    case bad
    case unknown
    case none

    public init(code: String) {
        switch code.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "G": self = .good
        case "B", "R": self = .bad
        case "U", "X", "Y", "E": self = .unknown
        default: self = .none
        }
    }

    public var title: String {
        switch self {
        case .good: "Good signature"
        case .bad: "Bad signature"
        case .unknown: "Signature not verified"
        case .none: "Not signed"
        }
    }

    public var explanation: String {
        switch self {
        case .good: "git verified the signature with a key you trust."
        case .bad: "The signature does not match the commit, or the key was revoked. The commit may have been changed after it was signed."
        case .unknown: "The commit is signed, but git cannot vouch for it: the key is unknown, untrusted or expired. For SSH signatures git needs gpg.ssh.allowedSignersFile; for OpenPGP, gpg must have the signer's public key."
        case .none: "The commit carries no signature."
        }
    }
}

public struct CommitSignatureDetails: Equatable, Sendable {
    public let status: CommitSignature
    public let signer: String
    public let key: String

    public init(status: CommitSignature, signer: String, key: String) {
        self.status = status
        self.signer = signer
        self.key = key
    }
}
