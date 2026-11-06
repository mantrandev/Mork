import Foundation

public struct RepositoryTabSession: Equatable, Sendable {
    public static let empty = RepositoryTabSession(tabs: [], selected: nil)

    public var tabs: [URL]
    public var selected: URL?

    public init(tabs: [URL], selected: URL?) {
        self.tabs = tabs
        self.selected = selected
    }

    public func normalized() -> RepositoryTabSession {
        var seen: Set<String> = []
        let unique = tabs.map(RecentRepositoryList.canonical).filter { seen.insert($0.path).inserted }
        let selectedPath = selected.map(RecentRepositoryList.canonical)?.path
        return RepositoryTabSession(tabs: unique, selected: unique.first { $0.path == selectedPath } ?? unique.first)
    }
}
