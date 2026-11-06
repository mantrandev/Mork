import Foundation

public protocol LoadLineHistoryUseCaseProtocol: Sendable {
    func execute(request: LineHistoryRequest, limit: Int) async throws -> [LineHistoryEntry]
}

public final class LoadLineHistoryUseCase: LoadLineHistoryUseCaseProtocol {
    private let lines: LineHistoryRepositoryProtocol

    public init(lines: LineHistoryRepositoryProtocol) {
        self.lines = lines
    }

    public func execute(request: LineHistoryRequest, limit: Int) async throws -> [LineHistoryEntry] {
        try await lines.lineHistory(of: request, limit: limit)
    }
}
