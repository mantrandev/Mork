import MorkDomain
import Foundation

public struct LocalChangesComparisonDependencies: Sendable {
    public let loadComparison: LoadLocalChangesComparisonUseCaseProtocol
    public let loadDiff: LoadLocalChangesDiffUseCaseProtocol

    public init(loadComparison: LoadLocalChangesComparisonUseCaseProtocol, loadDiff: LoadLocalChangesDiffUseCaseProtocol) {
        self.loadComparison = loadComparison
        self.loadDiff = loadDiff
    }
}
