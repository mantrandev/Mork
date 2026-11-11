import Foundation

public protocol UnhideFilesUseCaseProtocol: Sendable {
    func execute(paths: [String]) async throws
}

public final class UnhideFilesUseCase: UnhideFilesUseCaseProtocol {
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(workingCopy: WorkingCopyRepositoryProtocol) {
        self.workingCopy = workingCopy
    }

    public func execute(paths: [String]) async throws {
        guard !paths.isEmpty else { return }
        try await workingCopy.unhide(paths: paths)
    }
}
