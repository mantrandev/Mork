import Foundation

public protocol RevertCommitUseCaseProtocol: Sendable {
    func execute(commit: Commit, options: RevertOptions) async throws
}

public final class RevertCommitUseCase: RevertCommitUseCaseProtocol {
    private let revisions: RevisionRepositoryProtocol
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(revisions: RevisionRepositoryProtocol, workingCopy: WorkingCopyRepositoryProtocol) {
        self.revisions = revisions
        self.workingCopy = workingCopy
    }

    public func execute(commit: Commit, options: RevertOptions) async throws {
        try await workingCopy.requireCleanState()
        try await revisions.revert(commit, mainline: commit.mainline, options: options)
    }
}
