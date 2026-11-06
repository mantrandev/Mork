import Foundation

public protocol RepositoryWatcherProtocol: Sendable {
    func changes(in root: URL) -> AsyncStream<[String]>
}
