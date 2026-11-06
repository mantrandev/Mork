import Foundation

public protocol AbortMergeUseCaseProtocol: Sendable {
    func execute() async throws
}

public final class AbortMergeUseCase: AbortMergeUseCaseProtocol {
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(workingCopy: WorkingCopyRepositoryProtocol) {
        self.workingCopy = workingCopy
    }

    public func execute() async throws {
        guard try await workingCopy.state() == .merging else { return }
        try await workingCopy.abortMerge()
    }
}
