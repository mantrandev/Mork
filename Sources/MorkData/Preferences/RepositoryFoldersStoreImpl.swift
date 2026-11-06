import MorkDomain
import Foundation

public final class RepositoryFoldersStoreImpl: RepositoryFoldersRepositoryProtocol, @unchecked Sendable {
    public static let key = "repositoryManagerFolders"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func load() -> [URL] {
        (defaults.array(forKey: Self.key) as? [String] ?? []).map { URL(filePath: $0, directoryHint: .notDirectory) }
    }

    public func save(_ folders: [URL]) {
        defaults.set(folders.map(\.path), forKey: Self.key)
    }
}
