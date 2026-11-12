import Foundation

public protocol LoadWorkingCopyChangesUseCaseProtocol: Sendable {
    func execute(amending: Bool) async throws -> [FileChange]
}

public final class LoadWorkingCopyChangesUseCase: LoadWorkingCopyChangesUseCaseProtocol {
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(workingCopy: WorkingCopyRepositoryProtocol) {
        self.workingCopy = workingCopy
    }

    public func execute(amending: Bool) async throws -> [FileChange] {
        try await amending ? workingCopy.amendChanges() : workingCopy.changes()
    }
}
