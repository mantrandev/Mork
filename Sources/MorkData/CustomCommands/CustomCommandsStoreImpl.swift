import MorkDomain
import Foundation

public final class CustomCommandsStoreImpl: CustomCommandsRepositoryProtocol, @unchecked Sendable {
    public static let key = "customCommands"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func load() -> [CustomCommand] {
        guard let data = defaults.data(forKey: Self.key) else { return [] }
        return (try? JSONDecoder().decode([CustomCommand].self, from: data)) ?? []
    }

    public func save(_ commands: [CustomCommand]) {
        guard let data = try? JSONEncoder().encode(commands) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
