import MorkDomain
import Foundation

public struct SettingsDependencies: Sendable {
    public let loadSettings: LoadSettingsUseCaseProtocol
    public let saveSettings: SaveSettingsUseCaseProtocol
    public let loadGitInstallation: LoadGitInstallationUseCaseProtocol
    public let loadGlobalIdentity: LoadGitIdentityUseCaseProtocol
    public let saveGlobalIdentity: SaveGitIdentityUseCaseProtocol
    public let integration: IntegrationSettingsDependencies
    public let signing: SigningSettingsDependencies
    public let customCommands: CustomCommandsDependencies
    public let loadCommandLineTool: LoadCommandLineToolStatusUseCaseProtocol
    public let installCommandLineTool: InstallCommandLineToolUseCaseProtocol

    public init(
        loadSettings: LoadSettingsUseCaseProtocol,
        saveSettings: SaveSettingsUseCaseProtocol,
        loadGitInstallation: LoadGitInstallationUseCaseProtocol,
        loadGlobalIdentity: LoadGitIdentityUseCaseProtocol,
        saveGlobalIdentity: SaveGitIdentityUseCaseProtocol,
        integration: IntegrationSettingsDependencies,
        signing: SigningSettingsDependencies,
        customCommands: CustomCommandsDependencies,
        loadCommandLineTool: LoadCommandLineToolStatusUseCaseProtocol,
        installCommandLineTool: InstallCommandLineToolUseCaseProtocol
    ) {
        self.loadSettings = loadSettings
        self.saveSettings = saveSettings
        self.loadGitInstallation = loadGitInstallation
        self.loadGlobalIdentity = loadGlobalIdentity
        self.saveGlobalIdentity = saveGlobalIdentity
        self.integration = integration
        self.signing = signing
        self.customCommands = customCommands
        self.loadCommandLineTool = loadCommandLineTool
        self.installCommandLineTool = installCommandLineTool
    }
}

public struct RepositorySettingsDependencies: Sendable {
    public let loadLocalIdentity: LoadGitIdentityUseCaseProtocol
    public let saveLocalIdentity: SaveGitIdentityUseCaseProtocol
    public let loadGlobalIdentity: LoadGitIdentityUseCaseProtocol
    public let loadIgnoreFile: LoadIgnoreFileUseCaseProtocol
    public let saveIgnoreFile: SaveIgnoreFileUseCaseProtocol
    public let loadLocalCommitTemplate: LoadGitConfigValueUseCaseProtocol
    public let loadGlobalCommitTemplate: LoadGitConfigValueUseCaseProtocol
    public let saveLocalCommitTemplate: SaveGitConfigValueUseCaseProtocol
    public let signing: SigningSettingsDependencies

    public init(
        loadLocalIdentity: LoadGitIdentityUseCaseProtocol,
        saveLocalIdentity: SaveGitIdentityUseCaseProtocol,
        loadGlobalIdentity: LoadGitIdentityUseCaseProtocol,
        loadIgnoreFile: LoadIgnoreFileUseCaseProtocol,
        saveIgnoreFile: SaveIgnoreFileUseCaseProtocol,
        loadLocalCommitTemplate: LoadGitConfigValueUseCaseProtocol,
        loadGlobalCommitTemplate: LoadGitConfigValueUseCaseProtocol,
        saveLocalCommitTemplate: SaveGitConfigValueUseCaseProtocol,
        signing: SigningSettingsDependencies
    ) {
        self.loadLocalIdentity = loadLocalIdentity
        self.saveLocalIdentity = saveLocalIdentity
        self.loadGlobalIdentity = loadGlobalIdentity
        self.loadIgnoreFile = loadIgnoreFile
        self.saveIgnoreFile = saveIgnoreFile
        self.loadLocalCommitTemplate = loadLocalCommitTemplate
        self.loadGlobalCommitTemplate = loadGlobalCommitTemplate
        self.saveLocalCommitTemplate = saveLocalCommitTemplate
        self.signing = signing
    }
}
