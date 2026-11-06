import MorkDomain
import Foundation

public final class HistoryOptionsStoreImpl: HistoryOptionsRepositoryProtocol, @unchecked Sendable {
    public static let key = "historyOptions"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func load(for repository: URL) -> HistoryOptions? {
        guard let data = defaults.dictionary(forKey: Self.key)?[Self.identifier(of: repository)] as? Data else { return nil }
        return try? JSONDecoder().decode(HistoryOptions.self, from: data)
    }

    public func save(_ options: HistoryOptions, for repository: URL) {
        var stored = defaults.dictionary(forKey: Self.key) ?? [:]
        stored[Self.identifier(of: repository)] = try? JSONEncoder().encode(options)
        defaults.set(stored, forKey: Self.key)
    }

    private static func identifier(of repository: URL) -> String {
        repository.standardizedFileURL.path
    }
}
