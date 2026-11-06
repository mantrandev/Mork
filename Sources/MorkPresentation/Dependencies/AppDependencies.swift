import MorkDomain
import Foundation

public struct AppDependencies: Sendable {
    public let locateRepository: LocateRepositoryUseCaseProtocol
    public let initializeRepository: InitializeRepositoryUseCaseProtocol
    public let makeRepositoryDependencies: @Sendable (URL) -> RepositoryDependencies
    public let cloneRepository: CloneRepositoryUseCaseProtocol
    public let loadRecentRepositories: LoadRecentRepositoriesUseCaseProtocol
    public let rememberRecentRepository: RememberRecentRepositoryUseCaseProtocol
    public let clearRecentRepositories: ClearRecentRepositoriesUseCaseProtocol
    public let tabs: RepositoryTabsDependencies
    public let repositoryManager: RepositoryManagerDependencies
    public let settings: SettingsDependencies
    public let accounts: AccountsDependencies
    public let ssh: SSHDependencies
    public let loadAuthorAvatar: LoadAuthorAvatarUseCaseProtocol?

    public init(
        locateRepository: LocateRepositoryUseCaseProtocol,
        initializeRepository: InitializeRepositoryUseCaseProtocol,
        makeRepositoryDependencies: @escaping @Sendable (URL) -> RepositoryDependencies,
        cloneRepository: CloneRepositoryUseCaseProtocol,
        loadRecentRepositories: LoadRecentRepositoriesUseCaseProtocol,
        rememberRecentRepository: RememberRecentRepositoryUseCaseProtocol,
        clearRecentRepositories: ClearRecentRepositoriesUseCaseProtocol,
        tabs: RepositoryTabsDependencies,
        repositoryManager: RepositoryManagerDependencies,
        settings: SettingsDependencies,
        accounts: AccountsDependencies,
        ssh: SSHDependencies,
        loadAuthorAvatar: LoadAuthorAvatarUseCaseProtocol? = nil
    ) {
        self.locateRepository = locateRepository
        self.initializeRepository = initializeRepository
        self.makeRepositoryDependencies = makeRepositoryDependencies
        self.cloneRepository = cloneRepository
        self.loadRecentRepositories = loadRecentRepositories
        self.rememberRecentRepository = rememberRecentRepository
        self.clearRecentRepositories = clearRecentRepositories
        self.settings = settings
        self.accounts = accounts
        self.ssh = ssh
        self.loadAuthorAvatar = loadAuthorAvatar
        self.tabs = tabs
        self.repositoryManager = repositoryManager
    }
}

public struct RepositoryTabsDependencies: Sendable {
    public let loadTabs: LoadRepositoryTabsUseCaseProtocol
    public let saveTabs: SaveRepositoryTabsUseCaseProtocol
    public let checkRepositoryExists: CheckRepositoryExistsUseCaseProtocol
    public let loadWorkspaces: LoadWorkspacesUseCaseProtocol
    public let saveWorkspaces: SaveWorkspacesUseCaseProtocol
    public let loadTabAppearances: LoadTabAppearancesUseCaseProtocol
    public let saveTabAppearances: SaveTabAppearancesUseCaseProtocol

    public init(
        loadTabs: LoadRepositoryTabsUseCaseProtocol,
        saveTabs: SaveRepositoryTabsUseCaseProtocol,
        checkRepositoryExists: CheckRepositoryExistsUseCaseProtocol,
        loadWorkspaces: LoadWorkspacesUseCaseProtocol,
        saveWorkspaces: SaveWorkspacesUseCaseProtocol,
        loadTabAppearances: LoadTabAppearancesUseCaseProtocol,
        saveTabAppearances: SaveTabAppearancesUseCaseProtocol
    ) {
        self.loadTabs = loadTabs
        self.saveTabs = saveTabs
        self.checkRepositoryExists = checkRepositoryExists
        self.loadWorkspaces = loadWorkspaces
        self.saveWorkspaces = saveWorkspaces
        self.loadTabAppearances = loadTabAppearances
        self.saveTabAppearances = saveTabAppearances
    }
}
