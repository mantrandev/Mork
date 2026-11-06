import Foundation

public protocol ResetCurrentBranchUseCaseProtocol: Sendable {
    func execute(commit: Commit, mode: ResetMode) async throws
}

public final class ResetCurrentBranchUseCase: ResetCurrentBranchUseCaseProtocol {
    private let revisions: RevisionRepositoryProtocol
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(revisions: RevisionRepositoryProtocol, workingCopy: WorkingCopyRepositoryProtocol) {
        self.revisions = revisions
        self.workingCopy = workingCopy
    }

    public func execute(commit: Commit, mode: ResetMode) async throws {
        try await workingCopy.requireCleanState()
        try await revisions.reset(to: commit, mode: mode)
    }
}
