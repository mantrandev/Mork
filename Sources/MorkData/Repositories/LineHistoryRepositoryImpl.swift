import MorkDomain
import Foundation

public final class LineHistoryRepositoryImpl: LineHistoryRepositoryProtocol {
    private let executor: GitCommandExecuting

    public init(executor: GitCommandExecuting) {
        self.executor = executor
    }

    public func lineHistory(of request: LineHistoryRequest, limit: Int) async throws -> [LineHistoryEntry] {
        guard try await executor.hasHead() else { return [] }
        return LineHistoryParser.parse(try await executor.readLossless(LineHistoryParser.arguments(request, limit: limit)))
    }
}
