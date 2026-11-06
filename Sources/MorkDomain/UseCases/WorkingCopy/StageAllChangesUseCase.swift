import Foundation

public protocol StageAllChangesUseCaseProtocol: Sendable {
    func execute() async throws
}

public final class StageAllChangesUseCase: StageAllChangesUseCaseProtocol {
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(workingCopy: WorkingCopyRepositoryProtocol) {
        self.workingCopy = workingCopy
    }

    public func execute() async throws {
        try await workingCopy.stageAll()
    }
}
