import MorkDomain
import Foundation

extension AppViewModel {
    public var workspaces: [Workspace] { workspaceCatalog.workspaces }
    public var currentWorkspace: Workspace { workspaceCatalog.current }

    public func switchWorkspace(to id: UUID) async {
        guard isPrimaryWindow else { return }
        var catalog = workspaceCatalog
        let target = catalog.switchTo(id, saving: openSession)
        saveWorkspaces(catalog)
        guard let target else { return }
        await replaceTabs(with: target)
    }

    @discardableResult
    public func addWorkspace(named name: String? = nil) -> Workspace {
        var catalog = workspaceCatalog
        catalog.updateCurrentSession(openSession)
        let workspace = catalog.add(named: name)
        saveWorkspaces(catalog)
        return workspace
    }

    public func renameWorkspace(_ id: UUID, to name: String) {
        var catalog = workspaceCatalog
        do {
            try catalog.rename(id, to: name)
            catalog.updateCurrentSession(openSession)
            saveWorkspaces(catalog)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func deleteWorkspace(_ id: UUID) async {
        var catalog = workspaceCatalog
        do {
            catalog.updateCurrentSession(openSession)
            let next = try catalog.delete(id)
            saveWorkspaces(catalog)
            if let next { await replaceTabs(with: next) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func moveTab(_ tab: RepositoryViewModel, toWorkspace id: UUID) {
        guard isPrimaryWindow, index(of: tab) != nil else { return }
        var catalog = workspaceCatalog
        guard catalog.addTab(tab.url, to: id) else { return }
        removeTab(tab, remembering: false)
        catalog.updateCurrentSession(openSession)
        saveWorkspaces(catalog)
    }

    var openSession: RepositoryTabSession {
        let located = tabs.filter { !$0.isLocating }
        return RepositoryTabSession(tabs: located.map(\.url), selected: repository.flatMap { $0.isLocating ? nil : $0.url })
    }

    private func saveWorkspaces(_ catalog: WorkspaceCatalog) {
        guard isPrimaryWindow else { return }
        workspaceCatalog = catalog
        dependencies.tabs.saveWorkspaces.execute(catalog: catalog)
    }

    private func replaceTabs(with session: RepositoryTabSession) async {
        for tab in tabs { deactivate(tab) }
        repository = nil
        tabs = []
        await open(session: session)
        saveTabs()
    }
}
