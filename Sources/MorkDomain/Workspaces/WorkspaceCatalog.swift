import Foundation

public struct WorkspaceCatalog: Equatable, Sendable {
    public static let homeName = "Home"
    public static let workName = "Work"
    public static let newName = "New Workspace"
    static let legacyDefaultName = "Default"

    public private(set) var workspaces: [Workspace]
    public private(set) var currentID: UUID

    public init(workspaces: [Workspace], currentID: UUID) {
        let list = workspaces.isEmpty ? Self.starters(home: .empty) : Self.sorted(workspaces)
        self.workspaces = list
        self.currentID = list.contains { $0.id == currentID } ? currentID : list[0].id
    }

    public static func initial(session: RepositoryTabSession) -> WorkspaceCatalog {
        let workspaces = starters(home: session)
        return WorkspaceCatalog(workspaces: workspaces, currentID: workspaces[0].id)
    }

    public func migratingLegacyDefault() -> WorkspaceCatalog {
        guard let legacy = workspaces.first(where: { $0.name.caseInsensitiveCompare(Self.legacyDefaultName) == .orderedSame }),
              !isTaken(Self.homeName, except: nil) else { return self }
        var migrated = self
        try? migrated.rename(legacy.id, to: Self.homeName)
        if !migrated.isTaken(Self.workName, except: nil) { migrated.add(named: Self.workName) }
        return migrated
    }

    public var current: Workspace {
        workspaces[currentIndex]
    }

    @discardableResult
    public mutating func add(named name: String?) -> Workspace {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let base = trimmed.isEmpty ? Self.newName : trimmed
        var candidate = base
        var number = 2
        while isTaken(candidate, except: nil) {
            candidate = "\(base) \(number)"
            number += 1
        }
        let workspace = Workspace(name: candidate, session: .empty)
        workspaces = Self.sorted(workspaces + [workspace])
        return workspace
    }

    public mutating func rename(_ id: UUID, to name: String) throws {
        guard let index = index(of: id) else { throw WorkspaceError.unknown }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw WorkspaceError.emptyName }
        guard !isTaken(trimmed, except: id) else { throw WorkspaceError.duplicateName(trimmed) }
        workspaces[index].name = trimmed
        workspaces = Self.sorted(workspaces)
    }

    public mutating func delete(_ id: UUID) throws -> RepositoryTabSession? {
        guard let index = index(of: id) else { throw WorkspaceError.unknown }
        guard workspaces.count > 1 else { throw WorkspaceError.lastWorkspace }
        workspaces.remove(at: index)
        guard id == currentID else { return nil }
        currentID = workspaces[min(index, workspaces.count - 1)].id
        return current.session
    }

    public mutating func switchTo(_ id: UUID, saving session: RepositoryTabSession) -> RepositoryTabSession? {
        guard let index = index(of: id) else { return nil }
        updateCurrentSession(session)
        guard id != currentID else { return nil }
        currentID = id
        return workspaces[index].session
    }

    public mutating func addTab(_ repository: URL, to id: UUID) -> Bool {
        guard id != currentID, let index = index(of: id) else { return false }
        let path = RecentRepositoryList.canonical(repository).path
        var session = workspaces[index].session
        if !session.tabs.contains(where: { RecentRepositoryList.canonical($0).path == path }) {
            session.tabs.append(repository)
        }
        if session.selected == nil { session.selected = repository }
        workspaces[index].session = session
        return true
    }

    public mutating func updateCurrentSession(_ session: RepositoryTabSession) {
        workspaces[currentIndex].session = session
    }

    private var currentIndex: Int {
        index(of: currentID) ?? 0
    }

    private func index(of id: UUID) -> Int? {
        workspaces.firstIndex { $0.id == id }
    }

    private static func starters(home: RepositoryTabSession) -> [Workspace] {
        [Workspace(name: homeName, session: home), Workspace(name: workName, session: .empty)]
    }

    private static func sorted(_ workspaces: [Workspace]) -> [Workspace] {
        workspaces.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func isTaken(_ name: String, except id: UUID?) -> Bool {
        workspaces.contains { $0.id != id && $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }
}
