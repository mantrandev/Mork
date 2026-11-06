import Foundation

public struct Workspace: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var session: RepositoryTabSession

    public init(id: UUID = UUID(), name: String, session: RepositoryTabSession) {
        self.id = id
        self.name = name
        self.session = session
    }
}

public enum WorkspaceError: LocalizedError, Equatable, Sendable {
    case emptyName
    case duplicateName(String)
    case lastWorkspace
    case unknown

    public var errorDescription: String? {
        switch self {
        case .emptyName: "Give the workspace a name."
        case let .duplicateName(name): "A workspace named “\(name)” already exists."
        case .lastWorkspace: "The last workspace cannot be deleted."
        case .unknown: "This workspace no longer exists."
        }
    }
}
