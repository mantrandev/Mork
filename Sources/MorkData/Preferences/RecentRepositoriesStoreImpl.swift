import MorkDomain
import Foundation

public final class RecentRepositoriesStoreImpl: RecentRepositoriesRepositoryProtocol, @unchecked Sendable {
    public static let key = "recentRepositories"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func load() -> [URL] {
        (defaults.array(forKey: Self.key) as? [String] ?? []).map { URL(filePath: $0, directoryHint: .notDirectory) }
    }

    public func save(_ urls: [URL]) {
        defaults.set(urls.map(\.path), forKey: Self.key)
    }

    public func exists(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
