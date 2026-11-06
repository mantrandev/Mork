import Foundation

public protocol RepositoryTabsRepositoryProtocol: Sendable {
    func load() -> RepositoryTabSession
    func save(_ session: RepositoryTabSession)
    func exists(_ url: URL) -> Bool
}
