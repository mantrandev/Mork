import Foundation

public protocol LoadIgnoredFilesUseCaseProtocol: Sendable {
    func execute() async throws -> [FileChange]
}

public final class LoadIgnoredFilesUseCase: LoadIgnoredFilesUseCaseProtocol {
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(workingCopy: WorkingCopyRepositoryProtocol) {
        self.workingCopy = workingCopy
    }

    public func execute() async throws -> [FileChange] {
        try await workingCopy.ignoredFiles().filter(\.isIgnored)
    }
}
