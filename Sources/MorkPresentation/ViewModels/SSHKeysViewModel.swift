import MorkDomain
import Foundation
import Observation

@MainActor
@Observable
public final class SSHKeysViewModel {
    public private(set) var directoryPath: String
    public private(set) var keys: Loadable<[SSHKey]> = .idle
    public var selectedKeyID: String?
    public var newKeyName = "id_ed25519"
    public var email = ""
    public var passphrase = ""
    public var confirmation = ""
    public var testHost = "github.com"
    public private(set) var isGenerating = false
    public private(set) var isTesting = false
    public private(set) var connectionResult: SSHConnectionResult?
    public private(set) var errorMessage: String?
    public private(set) var notice: String?

    private let dependencies: SSHDependencies
    public let accounts: AccountsViewModel

    public init(dependencies: SSHDependencies, accounts: AccountsViewModel) {
        self.dependencies = dependencies
        self.accounts = accounts
        directoryPath = accounts.preferences.sshDirectory ?? dependencies.defaultDirectory.path
    }

    public var lessons: [String] { [Lessons.sshKeygen, Lessons.sshFingerprint, Lessons.sshPublicKey] }
    public var directory: URL { URL(fileURLWithPath: directoryPath) }
    public var passphrasesMatch: Bool { passphrase == confirmation }

    public var canGenerate: Bool {
        !isGenerating && passphrasesMatch
            && !newKeyName.trimmingCharacters(in: .whitespaces).isEmpty
            && !email.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public var uploadTargets: [Account] {
        accounts.readyAccounts.filter(\.provider.supportsSSHKeyUpload)
    }

    public var selectedKey: SSHKey? {
        guard case let .loaded(keys) = keys else { return nil }
        return keys.first { $0.id == selectedKeyID }
    }

    public func load() async {
        keys = .loading
        do {
            let loaded = try await dependencies.loadKeys.execute(directory: directory)
            keys = .loaded(loaded)
            if selectedKeyID == nil || !loaded.contains(where: { $0.id == selectedKeyID }) { selectedKeyID = loaded.first?.id }
        } catch {
            keys = .failed(error.localizedDescription)
        }
    }

    public func useDirectory(_ path: String) async {
        let expanded = (path.trimmingCharacters(in: .whitespacesAndNewlines) as NSString).expandingTildeInPath
        guard !expanded.isEmpty else { return }
        directoryPath = expanded
        accounts.updatePreferences { $0.sshDirectory = expanded }
        await load()
    }

    public func generate() async {
        guard canGenerate else {
            if !passphrasesMatch { errorMessage = "The passphrases do not match." }
            return
        }
        isGenerating = true
        defer { isGenerating = false }
        errorMessage = nil
        notice = nil
        do {
            let key = try await dependencies.generateKey.execute(directory: directory, name: newKeyName, email: email, passphrase: passphrase)
            passphrase = ""
            confirmation = ""
            await load()
            selectedKeyID = key.id
            notice = "Created \(key.name) and \(key.name).pub in \(directoryPath)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func copyPublicKey(_ key: SSHKey) async {
        errorMessage = nil
        do {
            dependencies.clipboard.copy(try await dependencies.readPublicKey.execute(key: key))
            notice = "Copied \(key.name).pub. Paste it in the SSH keys page of your Git host."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func add(_ key: SSHKey, to account: Account) async {
        errorMessage = nil
        notice = nil
        do {
            try await dependencies.addKeyToAccount.execute(key: key, account: account)
            notice = "Added \(key.name).pub to \(account.login) on \(account.server.displayName)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func testConnection(with key: SSHKey?) async {
        guard !isTesting else { return }
        isTesting = true
        defer { isTesting = false }
        connectionResult = nil
        do {
            connectionResult = try await dependencies.testConnection.execute(host: testHost, key: key)
        } catch {
            connectionResult = SSHConnectionResult(succeeded: false, message: error.localizedDescription)
        }
    }
}
