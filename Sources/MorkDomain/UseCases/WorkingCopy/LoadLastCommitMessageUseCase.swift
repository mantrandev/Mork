import Foundation

public protocol LoadLastCommitMessageUseCaseProtocol: Sendable {
    func execute() async throws -> String?
}

public final class LoadLastCommitMessageUseCase: LoadLastCommitMessageUseCaseProtocol {
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(workingCopy: WorkingCopyRepositoryProtocol) {
        self.workingCopy = workingCopy
    }

    public func execute() async throws -> String? {
        try await workingCopy.lastCommitMessage()
    }
}
