import MorkDomain
import Foundation

public struct StatisticsDependencies: Sendable {
    public let loadStatistics: LoadRepositoryStatisticsUseCaseProtocol

    public init(loadStatistics: LoadRepositoryStatisticsUseCaseProtocol) {
        self.loadStatistics = loadStatistics
    }
}
