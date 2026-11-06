import MorkDomain
import Foundation

public final class TabAppearanceStoreImpl: TabAppearanceStoreProtocol, @unchecked Sendable {
    public static let key = "tabAppearances.v1"

    private static let titleKey = "title"
    private static let colorKey = "color"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func load() -> TabAppearances {
        guard let stored = defaults.dictionary(forKey: Self.key) else { return TabAppearances() }
        let byPath = stored.compactMapValues { value -> TabAppearance? in
            guard let fields = value as? [String: Any] else { return nil }
            let title = fields[Self.titleKey] as? String
            let color = (fields[Self.colorKey] as? String).flatMap(TabColor.init(rawValue:))
            return TabAppearance(title: title, color: color)
        }
        return TabAppearances(byPath: byPath)
    }

    public func save(_ appearances: TabAppearances) {
        let stored = appearances.byPath.mapValues { appearance in
            var fields: [String: String] = [:]
            fields[Self.titleKey] = appearance.title
            fields[Self.colorKey] = appearance.color?.rawValue
            return fields
        }
        defaults.set(stored, forKey: Self.key)
    }
}
