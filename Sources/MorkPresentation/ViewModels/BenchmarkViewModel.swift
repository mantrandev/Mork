import MorkDomain
import Foundation
import Observation

@MainActor
@Observable
public final class BenchmarkViewModel: Identifiable {
    public enum State: Equatable, Sendable {
        case idle
        case running(BenchmarkProgress)
        case finished(BenchmarkReport)
        case failed(String)
        case cancelled
    }

    public static let runChoices = RunPerformanceBenchmarkUseCase.runChoices

    public let id = UUID()
    public let repositoryName: String
    public var runs = 10
    public var selection: BenchmarkResult.ID?
    public private(set) var state: State = .idle

    @ObservationIgnored private var task: Task<BenchmarkReport, Error>?
    @ObservationIgnored private var generation = 0
    private let runBenchmark: RunPerformanceBenchmarkUseCaseProtocol

    public init(repositoryName: String, runBenchmark: RunPerformanceBenchmarkUseCaseProtocol) {
        self.repositoryName = repositoryName
        self.runBenchmark = runBenchmark
    }

    public var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    public var report: BenchmarkReport? {
        if case let .finished(report) = state { return report }
        return nil
    }

    public var selectedResult: BenchmarkResult? {
        report?.results.first { $0.id == selection }
    }

    public func start() async {
        guard !isRunning else { return }
        generation += 1
        let current = generation
        state = .running(BenchmarkProgress(completed: 0, total: 0, command: ""))
        let (updates, continuation) = AsyncStream<BenchmarkProgress>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let run = runBenchmark
        let runs = runs
        let task = Task {
            defer { continuation.finish() }
            return try await run.execute(runs: runs) { continuation.yield($0) }
        }
        self.task = task
        for await update in updates where current == generation && isRunning {
            state = .running(update)
        }
        let outcome: State
        do {
            let report = try await task.value
            outcome = .finished(report)
            if current == generation { selection = report.results.first?.id }
        } catch is CancellationError {
            outcome = .cancelled
        } catch {
            outcome = .failed(error.localizedDescription)
        }
        guard current == generation else { return }
        state = outcome
    }

    public func cancel() {
        task?.cancel()
    }

    public static func milliseconds(_ value: Double) -> String {
        String(format: value < 10 ? "%.2f ms" : "%.1f ms", value)
    }
}
