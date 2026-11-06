import Foundation

public protocol ContinueOperationUseCaseProtocol: Sendable {
    func execute() async throws
}

public final class ContinueOperationUseCase: ContinueOperationUseCaseProtocol {
    private let revisions: RevisionRepositoryProtocol
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(revisions: RevisionRepositoryProtocol, workingCopy: WorkingCopyRepositoryProtocol) {
        self.revisions = revisions
        self.workingCopy = workingCopy
    }

    public func execute() async throws {
        guard let operation = try await workingCopy.state().revisionOperation else { return }
        try await revisions.continueOperation(operation)
    }
}
