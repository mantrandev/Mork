import Foundation

public protocol AbortOperationUseCaseProtocol: Sendable {
    func execute() async throws
}

public final class AbortOperationUseCase: AbortOperationUseCaseProtocol {
    private let revisions: RevisionRepositoryProtocol
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(revisions: RevisionRepositoryProtocol, workingCopy: WorkingCopyRepositoryProtocol) {
        self.revisions = revisions
        self.workingCopy = workingCopy
    }

    public func execute() async throws {
        guard let operation = try await workingCopy.state().revisionOperation else { return }
        try await revisions.abortOperation(operation)
    }
}
