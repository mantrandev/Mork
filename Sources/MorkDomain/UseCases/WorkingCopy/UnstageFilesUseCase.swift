import Foundation

public protocol UnstageFilesUseCaseProtocol: Sendable {
    func execute(paths: [String]) async throws
}

public final class UnstageFilesUseCase: UnstageFilesUseCaseProtocol {
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(workingCopy: WorkingCopyRepositoryProtocol) {
        self.workingCopy = workingCopy
    }

    public func execute(paths: [String]) async throws {
        guard !paths.isEmpty else { return }
        try await workingCopy.unstage(paths: paths)
    }
}
