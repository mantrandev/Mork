import Foundation

public protocol StageIgnoredFilesUseCaseProtocol: Sendable {
    func execute(paths: [String]) async throws
}

public final class StageIgnoredFilesUseCase: StageIgnoredFilesUseCaseProtocol {
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(workingCopy: WorkingCopyRepositoryProtocol) {
        self.workingCopy = workingCopy
    }

    public func execute(paths: [String]) async throws {
        guard !paths.isEmpty else { return }
        try await workingCopy.forceStage(paths: paths)
    }
}
