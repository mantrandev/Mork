import MorkDomain
import Foundation

public struct CommitDependencies: Sendable {
    public let loadCommitTemplate: LoadCommitTemplateUseCaseProtocol
    public let loadCommitSignatures: LoadCommitSignaturesUseCaseProtocol
    public let loadCommitMessages: LoadCommitMessagesUseCaseProtocol
    public let runCustomCommand: RunCustomCommandUseCaseProtocol

    public init(
        loadCommitTemplate: LoadCommitTemplateUseCaseProtocol,
        loadCommitSignatures: LoadCommitSignaturesUseCaseProtocol,
        loadCommitMessages: LoadCommitMessagesUseCaseProtocol,
        runCustomCommand: RunCustomCommandUseCaseProtocol
    ) {
        self.loadCommitTemplate = loadCommitTemplate
        self.loadCommitSignatures = loadCommitSignatures
        self.loadCommitMessages = loadCommitMessages
        self.runCustomCommand = runCustomCommand
    }
}

public struct SigningSettingsDependencies: Sendable {
    public let loadSettings: LoadSigningSettingsUseCaseProtocol
    public let saveSettings: SaveSigningSettingsUseCaseProtocol
    public let loadInherited: LoadSigningSettingsUseCaseProtocol?
    public let loadKeys: LoadSigningKeysUseCaseProtocol

    public init(
        loadSettings: LoadSigningSettingsUseCaseProtocol,
        saveSettings: SaveSigningSettingsUseCaseProtocol,
        loadInherited: LoadSigningSettingsUseCaseProtocol?,
        loadKeys: LoadSigningKeysUseCaseProtocol
    ) {
        self.loadSettings = loadSettings
        self.saveSettings = saveSettings
        self.loadInherited = loadInherited
        self.loadKeys = loadKeys
    }
}
