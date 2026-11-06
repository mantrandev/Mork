import MorkDomain
import Foundation

public protocol FolderPanelProtocol: Sendable {
    func chooseFolder(prompt: String) async -> URL?
}

public struct RepositoryManagerDependencies: Sendable {
    public let loadFolders: LoadRepositoryFoldersUseCaseProtocol
    public let addFolder: AddRepositoryFolderUseCaseProtocol
    public let removeFolder: RemoveRepositoryFolderUseCaseProtocol
    public let scanFolders: ScanRepositoryFoldersUseCaseProtocol
    public let loadStatus: LoadRepositoryStatusUseCaseProtocol
    public let loadWorktrees: LoadRepositoryWorktreesUseCaseProtocol
    public let loadOverview: LoadRepositoryOverviewUseCaseProtocol
    public let locateMainRepository: LocateMainRepositoryUseCaseProtocol
    public let folderPanel: FolderPanelProtocol

    public init(
        loadFolders: LoadRepositoryFoldersUseCaseProtocol,
        addFolder: AddRepositoryFolderUseCaseProtocol,
        removeFolder: RemoveRepositoryFolderUseCaseProtocol,
        scanFolders: ScanRepositoryFoldersUseCaseProtocol,
        loadStatus: LoadRepositoryStatusUseCaseProtocol,
        loadWorktrees: LoadRepositoryWorktreesUseCaseProtocol,
        loadOverview: LoadRepositoryOverviewUseCaseProtocol,
        locateMainRepository: LocateMainRepositoryUseCaseProtocol,
        folderPanel: FolderPanelProtocol
    ) {
        self.loadFolders = loadFolders
        self.addFolder = addFolder
        self.removeFolder = removeFolder
        self.scanFolders = scanFolders
        self.loadStatus = loadStatus
        self.loadWorktrees = loadWorktrees
        self.loadOverview = loadOverview
        self.locateMainRepository = locateMainRepository
        self.folderPanel = folderPanel
    }
}
