import MorkDomain
import Foundation

public final class SidebarOptionsStoreImpl: SidebarOptionsRepositoryProtocol, @unchecked Sendable {
    public static let key = "sidebarOptions"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults) { self.defaults = defaults }

    public func load(for repository: URL) -> SidebarOptions? {
        let identifier = repository.standardizedFileURL.path
        if let data = defaults.dictionary(forKey: Self.key)?[identifier] as? Data,
           let options = try? JSONDecoder().decode(SidebarOptions.self, from: data) {
            return options
        }
        guard let legacy = defaults.dictionary(forKey: HistoryOptionsStoreImpl.key)?[identifier] as? Data,
              let options = try? JSONDecoder().decode(SidebarOptions.self, from: legacy) else { return nil }
        save(options, for: repository)
        return options
    }

    public func save(_ options: SidebarOptions, for repository: URL) {
        var stored = defaults.dictionary(forKey: Self.key) ?? [:]
        stored[repository.standardizedFileURL.path] = try? JSONEncoder().encode(options)
        defaults.set(stored, forKey: Self.key)
    }
}
