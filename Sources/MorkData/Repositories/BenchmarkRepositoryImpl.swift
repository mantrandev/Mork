import MorkDomain
import Foundation

public final class BenchmarkRepositoryImpl: BenchmarkRepositoryProtocol {
    public typealias Discover = @Sendable (GitStreamingCommandExecuting) async throws -> Void

    private let directory: URL
    private let executor: GitStreamingCommandExecuting
    private let discover: Discover

    public init(directory: URL, discover: @escaping Discover) {
        self.directory = directory
        executor = ProcessGitCommandExecutor(directory: directory)
        self.discover = discover
    }

    public func refreshCommands() async throws -> [BenchmarkCommand] {
        let recorder = CommandRecordingExecutor(base: executor)
        try await discover(recorder)
        return recorder.commands
    }

    public func time(_ command: BenchmarkCommand) async throws -> Double {
        let clock = ContinuousClock()
        let started = clock.now
        _ = try await executor.run(command.arguments, input: command.input, environment: [:], kind: .read, allowedExitCodes: nil)
        let elapsed = clock.now - started
        return Double(elapsed.components.seconds) * 1_000 + Double(elapsed.components.attoseconds) / 1e15
    }

    public func trace(_ command: BenchmarkCommand) async throws -> [PerformanceTraceEntry] {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("mork-trace-\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(at: file) }
        _ = try await executor.run(command.arguments, input: command.input, environment: ["GIT_TRACE_PERFORMANCE": file.path], kind: .read, allowedExitCodes: nil)
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return [] }
        return PerformanceTraceEntry.parse(text)
    }
}
