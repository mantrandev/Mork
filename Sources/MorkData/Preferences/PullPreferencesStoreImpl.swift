import MorkDomain
import Foundation

public final class PullPreferencesStoreImpl: PullPreferencesRepositoryProtocol, @unchecked Sendable {
    public static let key = "pullModes"
    public static let autostashKey = "pullAutostash"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func pullMode(for repository: URL) -> PullMode? {
        stored()[Self.path(of: repository)].flatMap(PullMode.init(rawValue:))
    }

    public func savePullMode(_ mode: PullMode, for repository: URL) {
        var modes = stored()
        modes[Self.path(of: repository)] = mode.rawValue
        defaults.set(modes, forKey: Self.key)
    }

    public func autostash(for repository: URL) -> Bool? {
        (defaults.dictionary(forKey: Self.autostashKey) as? [String: Bool])?[Self.path(of: repository)]
    }

    public func saveAutostash(_ autostash: Bool, for repository: URL) {
        var values = defaults.dictionary(forKey: Self.autostashKey) as? [String: Bool] ?? [:]
        values[Self.path(of: repository)] = autostash
        defaults.set(values, forKey: Self.autostashKey)
    }

    private func stored() -> [String: String] {
        defaults.dictionary(forKey: Self.key) as? [String: String] ?? [:]
    }

    private static func path(of repository: URL) -> String {
        repository.standardizedFileURL.path
    }
}
