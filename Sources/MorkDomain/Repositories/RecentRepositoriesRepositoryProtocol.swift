import Foundation

public protocol RecentRepositoriesRepositoryProtocol: Sendable {
    func load() -> [URL]
    func save(_ urls: [URL])
    func exists(_ url: URL) -> Bool
}
