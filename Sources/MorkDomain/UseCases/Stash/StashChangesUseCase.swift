import Foundation

public protocol StashChangesUseCaseProtocol: Sendable {
    func execute(message: String) async throws
}

public final class StashChangesUseCase: StashChangesUseCaseProtocol {
    private let stashes: StashRepositoryProtocol
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(stashes: StashRepositoryProtocol, workingCopy: WorkingCopyRepositoryProtocol) {
        self.stashes = stashes
        self.workingCopy = workingCopy
    }

    public func execute(message: String) async throws {
        guard try await !workingCopy.changes().isEmpty else { throw GitDomainError.nothingToStash }
        try await stashes.save(message: message.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
