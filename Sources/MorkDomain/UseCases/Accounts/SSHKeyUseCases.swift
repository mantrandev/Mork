import Foundation

public protocol LoadSSHKeysUseCaseProtocol: Sendable {
    func execute(directory: URL) async throws -> [SSHKey]
}

public protocol GenerateSSHKeyUseCaseProtocol: Sendable {
    func execute(directory: URL, name: String, email: String, passphrase: String) async throws -> SSHKey
}

public protocol ReadPublicKeyUseCaseProtocol: Sendable {
    func execute(key: SSHKey) async throws -> String
}

public protocol TestSSHConnectionUseCaseProtocol: Sendable {
    func execute(host: String, key: SSHKey?) async throws -> SSHConnectionResult
}

public protocol AddSSHKeyToAccountUseCaseProtocol: Sendable {
    func execute(key: SSHKey, account: Account) async throws
}

public final class LoadSSHKeysUseCase: LoadSSHKeysUseCaseProtocol {
    private let keys: SSHKeyRepositoryProtocol

    public init(keys: SSHKeyRepositoryProtocol) {
        self.keys = keys
    }

    public func execute(directory: URL) async throws -> [SSHKey] {
        try await keys.keys(in: directory).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

public final class GenerateSSHKeyUseCase: GenerateSSHKeyUseCaseProtocol {
    public static let minimumPassphraseLength = 5
    private static let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.@"))

    private let keys: SSHKeyRepositoryProtocol

    public init(keys: SSHKeyRepositoryProtocol) {
        self.keys = keys
    }

    public func execute(directory: URL, name: String, email: String, passphrase: String) async throws -> SSHKey {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw SSHKeyError.emptyName }
        guard name.unicodeScalars.allSatisfy(Self.allowed.contains), !name.hasPrefix("."), !name.hasPrefix("-"), !name.hasSuffix(".pub") else {
            throw SSHKeyError.invalidName(name)
        }
        guard !email.isEmpty else { throw SSHKeyError.emptyComment }
        guard passphrase.isEmpty || passphrase.count >= Self.minimumPassphraseLength else { throw SSHKeyError.passphraseTooShort }
        let request = SSHKeyRequest(directory: directory, name: name, email: email, passphrase: passphrase)
        for file in [request.privateKeyURL, request.publicKeyURL] where keys.fileExists(at: file) {
            throw SSHKeyError.alreadyExists(path: file.path)
        }
        try await keys.generateKey(request)
        let created = try await keys.keys(in: directory).first { $0.publicKeyURL.standardizedFileURL == request.publicKeyURL.standardizedFileURL }
        guard let created else { throw SSHKeyError.commandFailed("ssh-keygen finished but \(request.publicKeyURL.path) is missing.") }
        return created
    }
}

public final class ReadPublicKeyUseCase: ReadPublicKeyUseCaseProtocol {
    private let keys: SSHKeyRepositoryProtocol

    public init(keys: SSHKeyRepositoryProtocol) {
        self.keys = keys
    }

    public func execute(key: SSHKey) async throws -> String {
        try await keys.publicKey(of: key).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public final class TestSSHConnectionUseCase: TestSSHConnectionUseCaseProtocol {
    private static let hostCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-:"))
    private static let successMarkers = ["successfully authenticated", "Welcome to GitLab", "authenticated via", "logged in as", "Hi there"]

    private let keys: SSHKeyRepositoryProtocol

    public init(keys: SSHKeyRepositoryProtocol) {
        self.keys = keys
    }

    public func execute(host: String, key: SSHKey?) async throws -> SSHConnectionResult {
        let host = try Self.normalized(host)
        let output = try await keys.testConnection(SSHConnectionRequest(host: host, identity: key?.hasPrivateKey == true ? key?.privateKeyURL : nil))
        let text = output.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if Self.successMarkers.contains(where: text.contains) {
            return SSHConnectionResult(succeeded: true, message: text)
        }
        if text.contains("Permission denied (publickey)") {
            return SSHConnectionResult(succeeded: false, message: "\(text)\nThe server does not know this key. Use Add to account, or paste the public key in the website's SSH keys page.")
        }
        if text.contains("Host key verification failed") {
            return SSHConnectionResult(succeeded: false, message: "\(text)\nThe server's host key changed since you last connected. Check ~/.ssh/known_hosts before trusting it.")
        }
        return SSHConnectionResult(succeeded: output.exitCode == 0, message: text.isEmpty ? "ssh exited with \(output.exitCode)." : text)
    }

    static func normalized(_ input: String) throws -> String {
        var host = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let scheme = host.range(of: "://") { host = String(host[scheme.upperBound...]) }
        if let at = host.lastIndex(of: "@") { host = String(host[host.index(after: at)...]) }
        while host.hasSuffix("/") { host.removeLast() }
        guard !host.isEmpty, !host.hasPrefix("-"), host.unicodeScalars.allSatisfy(hostCharacters.contains) else {
            throw SSHKeyError.invalidHost
        }
        return host
    }
}

public final class AddSSHKeyToAccountUseCase: AddSSHKeyToAccountUseCaseProtocol {
    private let keys: SSHKeyRepositoryProtocol
    private let secrets: AccountSecretStoreProtocol
    private let hosting: HostingServiceProtocol

    public init(keys: SSHKeyRepositoryProtocol, secrets: AccountSecretStoreProtocol, hosting: HostingServiceProtocol) {
        self.keys = keys
        self.secrets = secrets
        self.hosting = hosting
    }

    public func execute(key: SSHKey, account: Account) async throws {
        guard account.provider.supportsSSHKeyUpload else { throw SSHKeyError.uploadUnsupported(account.provider) }
        let credential = try await AccountCredentials.load(for: account, from: secrets)
        let publicKey = try await keys.publicKey(of: key).trimmingCharacters(in: .whitespacesAndNewlines)
        let title = "Mork: \(key.comment.isEmpty ? key.name : key.comment)"
        try await hosting.addSSHKey(server: account.server, credential: credential, title: title, key: publicKey)
    }
}
