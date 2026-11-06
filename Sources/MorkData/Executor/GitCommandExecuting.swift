import MorkDomain
import Foundation

public protocol GitCommandExecuting: Sendable {
    func run(
        _ arguments: [String],
        input: String?,
        environment: [String: String],
        kind: GitCommandKind,
        allowedExitCodes: Set<Int32>?
    ) async throws -> String

    func readLines(_ arguments: [String], matching lines: Set<String>) async throws -> [String]

    func runData(_ arguments: [String], kind: GitCommandKind, allowedExitCodes: Set<Int32>?) async throws -> Data
}

extension GitCommandExecuting {
    public func readLines(_ arguments: [String], matching lines: Set<String>) async throws -> [String] {
        GitOutputParser.lines(try await read(arguments)).filter { lines.contains($0) }
    }

    public func run(_ arguments: [String], input: String?, kind: GitCommandKind, allowedExitCodes: Set<Int32>?) async throws -> String {
        try await run(arguments, input: input, environment: [:], kind: kind, allowedExitCodes: allowedExitCodes)
    }

    public func run(_ arguments: [String], kind: GitCommandKind, allowedExitCodes: Set<Int32>?) async throws -> String {
        try await run(arguments, input: nil, kind: kind, allowedExitCodes: allowedExitCodes)
    }

    @discardableResult
    func read(_ arguments: [String], allowedExitCodes: Set<Int32>? = [0]) async throws -> String {
        try await run(arguments, kind: .read, allowedExitCodes: allowedExitCodes)
    }

    func readLossless(_ arguments: [String], allowedExitCodes: Set<Int32>? = [0]) async throws -> String {
        LosslessText.decode(try await runData(arguments, kind: .read, allowedExitCodes: allowedExitCodes))
    }

    @discardableResult
    func write(_ arguments: [String], input: String? = nil, environment: [String: String] = [:], allowedExitCodes: Set<Int32>? = [0]) async throws -> String {
        try await run(arguments, input: input, environment: environment, kind: .write, allowedExitCodes: allowedExitCodes)
    }

    func hasHead() async throws -> Bool {
        try await !read(["rev-parse", "--verify", "--quiet", "HEAD"], allowedExitCodes: [0, 1]).isEmpty
    }
}

public protocol GitStreamingCommandExecuting: GitCommandExecuting {
    func run(
        _ arguments: [String],
        kind: GitCommandKind,
        allowedExitCodes: Set<Int32>?,
        onProgress: @escaping @Sendable (String) -> Void
    ) async throws -> String

    func run(
        _ arguments: [String],
        environment: [String: String],
        notes: [String],
        kind: GitCommandKind,
        allowedExitCodes: Set<Int32>?,
        onProgress: @escaping @Sendable (String) -> Void
    ) async throws -> String
}

extension GitStreamingCommandExecuting {
    public func run(
        _ arguments: [String],
        environment: [String: String],
        notes: [String],
        kind: GitCommandKind,
        allowedExitCodes: Set<Int32>?,
        onProgress: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        try await run(arguments, kind: kind, allowedExitCodes: allowedExitCodes, onProgress: onProgress)
    }
}

extension ProcessGitCommandExecutor: GitStreamingCommandExecuting {}
