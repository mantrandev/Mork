import MorkData
import MorkDomain
import MorkPresentation
import Foundation

extension AppContainer {
    nonisolated static func makeExecutorFactory(logger: GitCommandLogging, services: AccountServices) -> @Sendable (URL) -> GitToolCommandExecuting {
        let credentials = services.credentials
        let askpass = services.askpass
        return { directory in
            CredentialedGitCommandExecutor(base: ProcessGitCommandExecutor(directory: directory, logger: logger), credentials: credentials, askpass: askpass)
        }
    }

    nonisolated static func makeAccountsDependencies(services: AccountServices) -> AccountsDependencies {
        let add = AddAccountUseCase(store: services.store, secrets: services.secrets, hosting: services.hosting)
        return AccountsDependencies(
            loadAccounts: LoadAccountsUseCase(store: services.store, secrets: services.secrets),
            addAccount: add,
            removeAccount: RemoveAccountUseCase(store: services.store, secrets: services.secrets),
            loadRepositories: LoadHostedRepositoriesUseCase(secrets: services.secrets, hosting: services.hosting),
            loadAvatar: LoadAvatarUseCase(avatars: services.avatars),
            loadPreferences: LoadAccountPreferencesUseCase(store: services.store),
            savePreferences: SaveAccountPreferencesUseCase(store: services.store),
            requestDeviceCode: RequestDeviceCodeUseCase(store: services.store, service: services.deviceFlow),
            completeDeviceFlow: CompleteDeviceFlowUseCase(service: services.deviceFlow, addAccount: add)
        )
    }

    nonisolated static func makeSSHDependencies(services: AccountServices) -> SSHDependencies {
        let keys = SSHKeyRepositoryImpl(runner: ProcessCommandRunner(), askpass: services.askpass)
        return SSHDependencies(
            loadKeys: LoadSSHKeysUseCase(keys: keys),
            generateKey: GenerateSSHKeyUseCase(keys: keys),
            readPublicKey: ReadPublicKeyUseCase(keys: keys),
            testConnection: TestSSHConnectionUseCase(keys: keys),
            addKeyToAccount: AddSSHKeyToAccountUseCase(keys: keys, secrets: services.secrets, hosting: services.hosting),
            defaultDirectory: services.sshDirectory,
            clipboard: AppKitClipboard()
        )
    }
}
