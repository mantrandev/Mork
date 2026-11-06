import Foundation

public protocol LoadFileHistoryUseCaseProtocol: Sendable {
    func execute(path: String, limit: Int) async throws -> [FileHistoryEntry]
}

public final class LoadFileHistoryUseCase: LoadFileHistoryUseCaseProtocol {
    private let files: FileInspectionRepositoryProtocol

    public init(files: FileInspectionRepositoryProtocol) {
        self.files = files
    }

    public func execute(path: String, limit: Int) async throws -> [FileHistoryEntry] {
        try await files.history(of: path, limit: limit)
    }
}
