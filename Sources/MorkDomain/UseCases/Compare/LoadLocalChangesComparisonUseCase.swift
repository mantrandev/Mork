import Foundation

public protocol LoadLocalChangesComparisonUseCaseProtocol: Sendable {
    func execute(commit: Commit) async throws -> LocalChangesComparison
}

public final class LoadLocalChangesComparisonUseCase: LoadLocalChangesComparisonUseCaseProtocol {
    private let comparison: LocalChangesComparisonRepositoryProtocol

    public init(comparison: LocalChangesComparisonRepositoryProtocol) {
        self.comparison = comparison
    }

    public func execute(commit: Commit) async throws -> LocalChangesComparison {
        async let changed = comparison.changedFiles(since: commit.hash)
        async let untracked = comparison.untrackedFiles()
        return LocalChangesComparison(changed: try await changed, untracked: try await untracked)
    }
}
