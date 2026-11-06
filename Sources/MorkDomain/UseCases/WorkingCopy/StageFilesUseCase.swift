import Foundation

public protocol StageFilesUseCaseProtocol: Sendable {
    func execute(paths: [String]) async throws
}

public final class StageFilesUseCase: StageFilesUseCaseProtocol {
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(workingCopy: WorkingCopyRepositoryProtocol) {
        self.workingCopy = workingCopy
    }

    public func execute(paths: [String]) async throws {
        guard !paths.isEmpty else { return }
        try await workingCopy.stage(paths: paths)
    }
}
