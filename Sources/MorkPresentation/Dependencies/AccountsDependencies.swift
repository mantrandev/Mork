import MorkDomain
import Foundation

public protocol ClipboardProtocol: Sendable {
    @MainActor func copy(_ text: String)
}

public struct AccountsDependencies: Sendable {
    public let loadAccounts: LoadAccountsUseCaseProtocol
    public let addAccount: AddAccountUseCaseProtocol
    public let removeAccount: RemoveAccountUseCaseProtocol
    public let loadRepositories: LoadHostedRepositoriesUseCaseProtocol
    public let loadAvatar: LoadAvatarUseCaseProtocol
    public let loadPreferences: LoadAccountPreferencesUseCaseProtocol
    public let savePreferences: SaveAccountPreferencesUseCaseProtocol
    public let requestDeviceCode: RequestDeviceCodeUseCaseProtocol
    public let completeDeviceFlow: CompleteDeviceFlowUseCaseProtocol

    public init(
        loadAccounts: LoadAccountsUseCaseProtocol,
        addAccount: AddAccountUseCaseProtocol,
        removeAccount: RemoveAccountUseCaseProtocol,
        loadRepositories: LoadHostedRepositoriesUseCaseProtocol,
        loadAvatar: LoadAvatarUseCaseProtocol,
        loadPreferences: LoadAccountPreferencesUseCaseProtocol,
        savePreferences: SaveAccountPreferencesUseCaseProtocol,
        requestDeviceCode: RequestDeviceCodeUseCaseProtocol,
        completeDeviceFlow: CompleteDeviceFlowUseCaseProtocol
    ) {
        self.loadAccounts = loadAccounts
        self.addAccount = addAccount
        self.removeAccount = removeAccount
        self.loadRepositories = loadRepositories
        self.loadAvatar = loadAvatar
        self.loadPreferences = loadPreferences
        self.savePreferences = savePreferences
        self.requestDeviceCode = requestDeviceCode
        self.completeDeviceFlow = completeDeviceFlow
    }
}

public struct SSHDependencies: Sendable {
    public let loadKeys: LoadSSHKeysUseCaseProtocol
    public let generateKey: GenerateSSHKeyUseCaseProtocol
    public let readPublicKey: ReadPublicKeyUseCaseProtocol
    public let testConnection: TestSSHConnectionUseCaseProtocol
    public let addKeyToAccount: AddSSHKeyToAccountUseCaseProtocol
    public let defaultDirectory: URL
    public let clipboard: ClipboardProtocol

    public init(
        loadKeys: LoadSSHKeysUseCaseProtocol,
        generateKey: GenerateSSHKeyUseCaseProtocol,
        readPublicKey: ReadPublicKeyUseCaseProtocol,
        testConnection: TestSSHConnectionUseCaseProtocol,
        addKeyToAccount: AddSSHKeyToAccountUseCaseProtocol,
        defaultDirectory: URL,
        clipboard: ClipboardProtocol
    ) {
        self.loadKeys = loadKeys
        self.generateKey = generateKey
        self.readPublicKey = readPublicKey
        self.testConnection = testConnection
        self.addKeyToAccount = addKeyToAccount
        self.defaultDirectory = defaultDirectory
        self.clipboard = clipboard
    }
}
