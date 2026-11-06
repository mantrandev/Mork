import MorkDomain
import Foundation

public final class RepositoryTabsStoreImpl: RepositoryTabsRepositoryProtocol, @unchecked Sendable {
    public static let tabsKey = "openRepositoryTabs"
    public static let selectedKey = "selectedRepositoryTab"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func load() -> RepositoryTabSession {
        let tabs = (defaults.array(forKey: Self.tabsKey) as? [String] ?? []).map { URL(filePath: $0, directoryHint: .notDirectory) }
        let selected = (defaults.object(forKey: Self.selectedKey) as? String).map { URL(filePath: $0, directoryHint: .notDirectory) }
        return RepositoryTabSession(tabs: tabs, selected: tabs.isEmpty ? nil : selected)
    }

    public func save(_ session: RepositoryTabSession) {
        defaults.set(session.tabs.map(\.path), forKey: Self.tabsKey)
        if let selected = session.selected {
            defaults.set(selected.path, forKey: Self.selectedKey)
        } else {
            defaults.removeObject(forKey: Self.selectedKey)
        }
    }

    public func exists(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
