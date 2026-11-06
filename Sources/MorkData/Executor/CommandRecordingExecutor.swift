import MorkDomain
import Foundation
import os

public final class CommandRecordingExecutor: GitStreamingCommandExecuting {
    private let base: GitStreamingCommandExecuting
    private let recorded = OSAllocatedUnfairLock<[BenchmarkCommand]>(initialState: [])

    public init(base: GitStreamingCommandExecuting) {
        self.base = base
    }

    public var commands: [BenchmarkCommand] {
        var seen: Set<BenchmarkCommand> = []
        return recorded.withLock { $0 }.filter { seen.insert($0).inserted }
    }

    public func run(_ arguments: [String], input: String?, environment: [String: String], kind: GitCommandKind, allowedExitCodes: Set<Int32>?) async throws -> String {
        record(arguments, input: input)
        return try await base.run(arguments, input: input, environment: environment, kind: kind, allowedExitCodes: allowedExitCodes)
    }

    public func readLines(_ arguments: [String], matching lines: Set<String>) async throws -> [String] {
        record(arguments, input: nil)
        return try await base.readLines(arguments, matching: lines)
    }

    public func runData(_ arguments: [String], kind: GitCommandKind, allowedExitCodes: Set<Int32>?) async throws -> Data {
        record(arguments, input: nil)
        return try await base.runData(arguments, kind: kind, allowedExitCodes: allowedExitCodes)
    }

    public func run(_ arguments: [String], kind: GitCommandKind, allowedExitCodes: Set<Int32>?, onProgress: @escaping @Sendable (String) -> Void) async throws -> String {
        record(arguments, input: nil)
        return try await base.run(arguments, kind: kind, allowedExitCodes: allowedExitCodes, onProgress: onProgress)
    }

    private func record(_ arguments: [String], input: String?) {
        recorded.withLock { $0.append(BenchmarkCommand(arguments: arguments, input: input)) }
    }
}
