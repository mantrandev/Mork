import Foundation

public protocol UnstageFromAmendUseCaseProtocol: Sendable {
    func execute(paths: [String]) async throws
}

public final class UnstageFromAmendUseCase: UnstageFromAmendUseCaseProtocol {
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(workingCopy: WorkingCopyRepositoryProtocol) {
        self.workingCopy = workingCopy
    }

    public func execute(paths: [String]) async throws {
        guard !paths.isEmpty else { return }
        try await workingCopy.unstageFromAmend(paths: paths)
    }
}
