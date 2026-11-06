import Foundation

public protocol ConcludeMergeUseCaseProtocol: Sendable {
    func execute() async throws
}

public final class ConcludeMergeUseCase: ConcludeMergeUseCaseProtocol {
    private let conflicts: ConflictRepositoryProtocol
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(conflicts: ConflictRepositoryProtocol, workingCopy: WorkingCopyRepositoryProtocol) {
        self.conflicts = conflicts
        self.workingCopy = workingCopy
    }

    public func execute() async throws {
        guard try await workingCopy.state() == .merging else { return }
        let remaining = try await workingCopy.changes().filter(\.isConflicted).count
        guard remaining == 0 else { throw ConflictError.unresolvedFiles(remaining) }
        try await conflicts.concludeMerge()
    }
}
