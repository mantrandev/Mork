import Foundation

public protocol TabAppearanceStoreProtocol: Sendable {
    func load() -> TabAppearances
    func save(_ appearances: TabAppearances)
}
