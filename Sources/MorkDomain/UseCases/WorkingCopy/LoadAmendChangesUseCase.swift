import Foundation

public protocol LoadAmendChangesUseCaseProtocol: Sendable {
    func execute() async throws -> [FileChange]
}

public final class LoadAmendChangesUseCase: LoadAmendChangesUseCaseProtocol {
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(workingCopy: WorkingCopyRepositoryProtocol) {
        self.workingCopy = workingCopy
    }

    public func execute() async throws -> [FileChange] {
        try await workingCopy.amendChanges()
    }
}
