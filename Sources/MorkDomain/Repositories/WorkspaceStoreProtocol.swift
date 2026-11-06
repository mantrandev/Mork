import Foundation

public protocol WorkspaceStoreProtocol: Sendable {
    func load() -> WorkspaceCatalog?
    func save(_ catalog: WorkspaceCatalog)
}
