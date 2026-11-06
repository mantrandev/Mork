import Foundation

public protocol DiscardFileChangesUseCaseProtocol: Sendable {
    func execute(change: FileChange) async throws
}

public final class DiscardFileChangesUseCase: DiscardFileChangesUseCaseProtocol {
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(workingCopy: WorkingCopyRepositoryProtocol) {
        self.workingCopy = workingCopy
    }

    public func execute(change: FileChange) async throws {
        guard change.hasWorktreeChanges else { return }
        try await workingCopy.discard(change)
    }
}
