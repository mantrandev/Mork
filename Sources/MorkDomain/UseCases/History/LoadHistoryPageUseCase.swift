import Foundation

public struct HistoryPage: Equatable, Sendable {
    public let rows: [GraphRow]
    public let cursor: HistoryCursor

    public init(rows: [GraphRow], cursor: HistoryCursor) {
        self.rows = rows
        self.cursor = cursor
    }
}

public protocol LoadHistoryPageUseCaseProtocol: Sendable {
    func execute(after cursor: HistoryCursor, limit: Int, options: HistoryOptions) async throws -> HistoryPage
}

public final class LoadHistoryPageUseCase: LoadHistoryPageUseCaseProtocol {
    private let history: HistoryRepositoryProtocol

    public init(history: HistoryRepositoryProtocol) {
        self.history = history
    }

    public func execute(after cursor: HistoryCursor, limit: Int, options: HistoryOptions) async throws -> HistoryPage {
        guard !cursor.isComplete else { return HistoryPage(rows: [], cursor: cursor) }
        let commits = try await history.history(limit: limit, skip: cursor.loadedCommits, options: options)
        var lanes = cursor.lanes
        let rows = CommitGraphLayout.layout(commits, lanes: &lanes)
        return HistoryPage(rows: rows, cursor: cursor.advanced(over: commits, lanes: lanes, limit: limit))
    }
}
