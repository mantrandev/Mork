import Foundation

public protocol LoadAmendDiffUseCaseProtocol: Sendable {
    func execute(change: FileChange) async throws -> String
}

public final class LoadAmendDiffUseCase: LoadAmendDiffUseCaseProtocol {
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(workingCopy: WorkingCopyRepositoryProtocol) {
        self.workingCopy = workingCopy
    }

    public func execute(change: FileChange) async throws -> String {
        try await workingCopy.amendDiff(for: change)
    }
}
