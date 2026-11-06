import Foundation

public protocol BenchmarkRepositoryProtocol: Sendable {
    func refreshCommands() async throws -> [BenchmarkCommand]
    func time(_ command: BenchmarkCommand) async throws -> Double
    func trace(_ command: BenchmarkCommand) async throws -> [PerformanceTraceEntry]
}
