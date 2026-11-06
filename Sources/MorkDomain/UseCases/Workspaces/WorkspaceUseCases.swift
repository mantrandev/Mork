import Foundation

public protocol LoadWorkspacesUseCaseProtocol: Sendable {
    func execute() -> WorkspaceCatalog
}

public protocol SaveWorkspacesUseCaseProtocol: Sendable {
    func execute(catalog: WorkspaceCatalog)
}

public final class LoadWorkspacesUseCase: LoadWorkspacesUseCaseProtocol {
    private let store: WorkspaceStoreProtocol
    private let tabs: RepositoryTabsRepositoryProtocol

    public init(store: WorkspaceStoreProtocol, tabs: RepositoryTabsRepositoryProtocol) {
        self.store = store
        self.tabs = tabs
    }

    public func execute() -> WorkspaceCatalog {
        let session = tabs.load()
        guard var catalog = store.load()?.migratingLegacyDefault() else { return .initial(session: session) }
        catalog.updateCurrentSession(session)
        return catalog
    }
}

public final class SaveWorkspacesUseCase: SaveWorkspacesUseCaseProtocol {
    private let store: WorkspaceStoreProtocol
    private let tabs: RepositoryTabsRepositoryProtocol

    public init(store: WorkspaceStoreProtocol, tabs: RepositoryTabsRepositoryProtocol) {
        self.store = store
        self.tabs = tabs
    }

    public func execute(catalog: WorkspaceCatalog) {
        store.save(catalog)
        tabs.save(catalog.current.session)
    }
}
