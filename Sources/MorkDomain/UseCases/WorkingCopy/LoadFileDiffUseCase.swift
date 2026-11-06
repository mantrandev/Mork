import Foundation

public protocol LoadFileDiffUseCaseProtocol: Sendable {
    func execute(change: FileChange, staged: Bool) async throws -> String
}

public final class LoadFileDiffUseCase: LoadFileDiffUseCaseProtocol {
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(workingCopy: WorkingCopyRepositoryProtocol) {
        self.workingCopy = workingCopy
    }

    public func execute(change: FileChange, staged: Bool) async throws -> String {
        try await workingCopy.diff(for: change, staged: staged)
    }
}
