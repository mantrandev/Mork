import MorkDomain
import Foundation

public final class SettingsStoreImpl: SettingsRepositoryProtocol, DiffOptionsProviding, @unchecked Sendable {
    public static let key = "appSettings"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func load() -> AppSettings? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(AppSettings.self, from: data)
    }

    public func save(_ settings: AppSettings) {
        defaults.set(try? JSONEncoder().encode(settings), forKey: Self.key)
    }

    public func diffOptions() -> DiffOptions {
        load()?.normalized().diff.options ?? .standard
    }
}
