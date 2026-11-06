import Foundation

public protocol RepositoryScannerProtocol: Sendable {
    func scan(folder: URL, maxDepth: Int) async -> RepositoryScan
}

public protocol RepositoryFoldersRepositoryProtocol: Sendable {
    func load() -> [URL]
    func save(_ folders: [URL])
}

public protocol RepositoryInspectorProtocol: Sendable {
    func status(of repository: URL) async throws -> RepositoryStatusSummary
    func worktrees(of repository: URL) async throws -> [Worktree]
    func commonDirectory(of repository: URL) async throws -> URL
    func overview(of repository: URL) async throws -> RepositoryOverview
}
