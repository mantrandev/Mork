import MorkDomain
import Foundation

public final class AccountStoreImpl: AccountStoreProtocol, @unchecked Sendable {
    public static let accountsKey = "accounts"
    public static let preferencesKey = "accountPreferences"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func accounts() -> [Account] {
        guard let data = defaults.data(forKey: Self.accountsKey) else { return [] }
        return (try? JSONDecoder().decode([Account].self, from: data)) ?? []
    }

    public func save(_ accounts: [Account]) {
        defaults.set(try? JSONEncoder().encode(accounts), forKey: Self.accountsKey)
    }

    public func preferences() -> AccountPreferences {
        guard let data = defaults.data(forKey: Self.preferencesKey) else { return AccountPreferences() }
        return (try? JSONDecoder().decode(AccountPreferences.self, from: data)) ?? AccountPreferences()
    }

    public func save(_ preferences: AccountPreferences) {
        defaults.set(try? JSONEncoder().encode(preferences), forKey: Self.preferencesKey)
    }
}
