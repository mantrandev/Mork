import MorkDomain
import Foundation

public final class WorkspaceStoreImpl: WorkspaceStoreProtocol, @unchecked Sendable {
    public static let key = "workspaces.v1"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func load() -> WorkspaceCatalog? {
        guard let data = defaults.data(forKey: Self.key),
              let stored = try? JSONDecoder().decode(StoredCatalog.self, from: data)
        else { return nil }
        return WorkspaceCatalog(workspaces: stored.workspaces.map(\.workspace), currentID: stored.currentID)
    }

    public func save(_ catalog: WorkspaceCatalog) {
        let stored = StoredCatalog(workspaces: catalog.workspaces.map(StoredWorkspace.init), currentID: catalog.currentID)
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: Self.key)
    }
}

private struct StoredCatalog: Codable {
    let workspaces: [StoredWorkspace]
    let currentID: UUID
}

private struct StoredWorkspace: Codable {
    let id: UUID
    let name: String
    let tabs: [String]
    let selected: String?

    init(_ workspace: Workspace) {
        id = workspace.id
        name = workspace.name
        tabs = workspace.session.tabs.map(\.path)
        selected = workspace.session.selected?.path
    }

    var workspace: Workspace {
        let urls = tabs.map { URL(filePath: $0, directoryHint: .notDirectory) }
        let selection = selected.map { URL(filePath: $0, directoryHint: .notDirectory) }
        return Workspace(id: id, name: name, session: RepositoryTabSession(tabs: urls, selected: selection))
    }
}
