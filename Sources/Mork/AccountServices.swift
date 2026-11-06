import MorkData
import MorkDomain
import Foundation

struct AccountServices: Sendable {
    let store: AccountStoreProtocol
    let secrets: AccountSecretStoreProtocol
    let hosting: HostingServiceProtocol
    let deviceFlow: DeviceFlowServiceProtocol
    let avatars: AvatarRepositoryProtocol
    let authorAvatars: AuthorAvatarRepositoryProtocol
    let askpass: AskpassScripts
    let sshDirectory: URL

    var credentials: GitCredentialProviding { ResolveGitCredentialsUseCase(store: store, secrets: secrets) }

    static func make(defaults: UserDefaults, options: LaunchOptions) -> AccountServices {
        let manager = FileManager.default
        let support = options.supportDirectory
            ?? manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent(AppEnvironment.current.dataFolder)
        let caches = options.supportDirectory?.appendingPathComponent("Caches")
            ?? manager.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent(AppEnvironment.current.dataFolder)
        let session = URLSession(configuration: .ephemeral)
        let hosting: HostingServiceProtocol = options.hostingFixture.map(FixtureHostingService.init) ?? HostingServiceImpl(session: session)
        return AccountServices(
            store: AccountStoreImpl(defaults: defaults),
            secrets: KeychainSecretStore(servicePrefix: options.keychainService ?? AppEnvironment.current.keychainPrefix),
            hosting: hosting,
            deviceFlow: DeviceFlowServiceImpl(session: session),
            avatars: AvatarCacheImpl(directory: caches.appendingPathComponent("avatars"), session: session),
            authorAvatars: options.offlineAvatars ? OfflineAuthorAvatars() : AuthorAvatarRepositoryImpl(directory: caches.appendingPathComponent("author-avatars"), session: session),
            askpass: AskpassScripts(directory: support.appendingPathComponent("askpass")),
            sshDirectory: options.sshDirectory ?? manager.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")
        )
    }
}

struct OfflineAuthorAvatars: AuthorAvatarRepositoryProtocol {
    func avatar(forEmail email: String) async throws -> Data {
        throw AuthorAvatarError.unavailable
    }
}
