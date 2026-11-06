import Foundation

public protocol RunPerformanceBenchmarkUseCaseProtocol: Sendable {
    func execute(runs: Int, progress: @escaping @Sendable (BenchmarkProgress) -> Void) async throws -> BenchmarkReport
}

public final class RunPerformanceBenchmarkUseCase: RunPerformanceBenchmarkUseCaseProtocol {
    public static let runChoices = [5, 10, 20]

    private let benchmark: BenchmarkRepositoryProtocol

    public init(benchmark: BenchmarkRepositoryProtocol) {
        self.benchmark = benchmark
    }

    public func execute(runs: Int, progress: @escaping @Sendable (BenchmarkProgress) -> Void) async throws -> BenchmarkReport {
        let runs = max(1, runs)
        let commands = try await benchmark.refreshCommands()
        let total = commands.count * (runs + 1)
        var completed = 0
        var results: [BenchmarkResult] = []
        for command in commands {
            var samples: [Double] = []
            for _ in 0..<runs {
                try Task.checkCancellation()
                progress(BenchmarkProgress(completed: completed, total: total, command: command.commandLine))
                samples.append(try await benchmark.time(command))
                completed += 1
            }
            try Task.checkCancellation()
            progress(BenchmarkProgress(completed: completed, total: total, command: command.commandLine))
            let trace = (try? await benchmark.trace(command)) ?? []
            completed += 1
            results.append(BenchmarkResult(command: command, samples: samples, trace: trace))
        }
        progress(BenchmarkProgress(completed: total, total: total, command: ""))
        return BenchmarkReport(runs: runs, results: results.sorted { $0.median > $1.median })
    }
}
