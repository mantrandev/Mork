import Foundation

public protocol BlameFileUseCaseProtocol: Sendable {
    func execute(path: String, commit: Commit?) async throws -> [BlameBlock]
}

public final class BlameFileUseCase: BlameFileUseCaseProtocol {
    private let files: FileInspectionRepositoryProtocol

    public init(files: FileInspectionRepositoryProtocol) {
        self.files = files
    }

    public func execute(path: String, commit: Commit?) async throws -> [BlameBlock] {
        BlameParser.blocks(try await files.blame(of: path, at: commit))
    }
}
