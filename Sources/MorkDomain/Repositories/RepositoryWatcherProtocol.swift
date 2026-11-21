import Foundation

public protocol RepositoryWatcherProtocol: Sendable {
    func changes(in root: URL) -> AsyncStream<RepositoryChanges>
}

public protocol IgnoredPathsRepositoryProtocol: Sendable {
    func ignoredPaths(_ paths: [String]) async throws -> Set<String>
}
