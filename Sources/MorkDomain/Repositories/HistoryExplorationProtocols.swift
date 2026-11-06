import Foundation

extension HistoryRepositoryProtocol {
    public func history(limit: Int) async throws -> [Commit] {
        try await history(limit: limit, options: .standard)
    }
}

public protocol CommitSearchRepositoryProtocol: Sendable {
    func search(_ query: CommitSearchQuery, options: HistoryOptions, limit: Int) async throws -> [Commit]
    func commit(revision: String) async throws -> Commit
}

public protocol ReflogRepositoryProtocol: Sendable {
    func reflog(limit: Int) async throws -> [ReflogEntry]
}

public protocol FileInspectionRepositoryProtocol: Sendable {
    func history(of path: String, limit: Int) async throws -> [FileHistoryEntry]
    func blame(of path: String, at commit: Commit?) async throws -> [BlameLine]
}

public protocol HistoryOptionsRepositoryProtocol: Sendable {
    func load(for repository: URL) -> HistoryOptions?
    func save(_ options: HistoryOptions, for repository: URL)
}

public protocol LineHistoryRepositoryProtocol: Sendable {
    func lineHistory(of request: LineHistoryRequest, limit: Int) async throws -> [LineHistoryEntry]
}
