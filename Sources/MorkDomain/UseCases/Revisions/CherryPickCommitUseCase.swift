import Foundation

public protocol CherryPickCommitUseCaseProtocol: Sendable {
    func execute(commit: Commit, options: CherryPickOptions) async throws
}

public final class CherryPickCommitUseCase: CherryPickCommitUseCaseProtocol {
    private let revisions: RevisionRepositoryProtocol
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(revisions: RevisionRepositoryProtocol, workingCopy: WorkingCopyRepositoryProtocol) {
        self.revisions = revisions
        self.workingCopy = workingCopy
    }

    public func execute(commit: Commit, options: CherryPickOptions) async throws {
        try await workingCopy.requireCleanState()
        try await revisions.cherryPick(commit, mainline: commit.mainline, options: options)
    }
}
