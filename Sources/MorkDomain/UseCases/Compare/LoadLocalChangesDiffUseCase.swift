import Foundation

public protocol LoadLocalChangesDiffUseCaseProtocol: Sendable {
    func execute(commit: Commit, file: ComparedFile) async throws -> String
}

public final class LoadLocalChangesDiffUseCase: LoadLocalChangesDiffUseCaseProtocol {
    private let comparison: LocalChangesComparisonRepositoryProtocol

    public init(comparison: LocalChangesComparisonRepositoryProtocol) {
        self.comparison = comparison
    }

    public func execute(commit: Commit, file: ComparedFile) async throws -> String {
        if file.isUntracked {
            return try await comparison.untrackedDiff(path: file.path)
        }
        return try await comparison.diff(since: commit.hash, file: file.change)
    }
}
