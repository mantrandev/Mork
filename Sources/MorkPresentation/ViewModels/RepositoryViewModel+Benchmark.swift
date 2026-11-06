import MorkDomain
import Foundation

extension RepositoryViewModel {
    public func showBenchmark() {
        advanced.benchmark = BenchmarkViewModel(repositoryName: name, runBenchmark: dependencies.advanced.runBenchmark)
    }

    public func closeBenchmark() {
        advanced.benchmark?.cancel()
        advanced.benchmark = nil
    }
}
