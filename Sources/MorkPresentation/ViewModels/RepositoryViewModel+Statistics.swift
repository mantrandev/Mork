import MorkDomain
import Foundation

extension RepositoryViewModel {
    public func showStatistics() async {
        let session = StatisticsViewModel(repositoryName: name, loadStatistics: dependencies.statistics.loadStatistics)
        statistics = session
        await session.load()
    }
}
