import MorkDomain
import Foundation

public final class ProcessGitCommandExecutor: GitCommandExecuting {
    private static let queue = DispatchQueue(label: "mork.git", qos: .userInitiated, attributes: .concurrent)

    let directory: URL
    let logger: GitCommandLogging?

    public init(directory: URL, logger: GitCommandLogging? = nil) {
        self.directory = directory
        self.logger = logger
    }

    public func run(
        _ arguments: [String],
        input: String?,
        environment: [String: String],
        kind: GitCommandKind,
        allowedExitCodes: Set<Int32>?
    ) async throws -> String {
        try await execute(arguments, input: input, environment: environment, kind: kind, allowedExitCodes: allowedExitCodes).stdout
    }

    public func runData(_ arguments: [String], kind: GitCommandKind, allowedExitCodes: Set<Int32>?) async throws -> Data {
        try await execute(arguments, input: nil, environment: [:], kind: kind, allowedExitCodes: allowedExitCodes, summarizesBinary: true).stdoutData
    }

    public func run(
        _ arguments: [String],
        input: String?,
        environment: [String: String],
        notes: [String],
        kind: GitCommandKind,
        allowedExitCodes: Set<Int32>?
    ) async throws -> String {
        try await execute(arguments, input: input, environment: environment, notes: notes, kind: kind, allowedExitCodes: allowedExitCodes).stdout
    }

    public func readLines(_ arguments: [String], matching lines: Set<String>) async throws -> [String] {
        GitOutputParser.lines(try await execute(arguments, input: nil, environment: [:], kind: .read, allowedExitCodes: [0], keepingOutputLines: lines).stdout)
    }

    private func execute(
        _ arguments: [String],
        input: String?,
        environment: [String: String],
        notes: [String] = [],
        kind: GitCommandKind,
        allowedExitCodes: Set<Int32>?,
        summarizesBinary: Bool = false,
        keepingOutputLines: Set<String>? = nil
    ) async throws -> ProcessOutput {
        let started = Date()
        let directory = directory
        let output = try await withCheckedThrowingContinuation { continuation in
            Self.queue.async {
                continuation.resume(with: Result {
                    try ProcessRunner.run(arguments, in: directory, input: input.map(LosslessText.encode), environment: environment, keepingOutputLines: keepingOutputLines)
                })
            }
        }
        let record = GitCommandRecord(
            arguments: arguments,
            kind: kind,
            exitCode: output.exitCode,
            stdout: summarizesBinary && Self.isBinary(output.stdoutData) ? "Binary output, \(output.stdoutData.count) bytes" : output.stdout,
            stderr: output.stderr,
            startedAt: started,
            duration: Date().timeIntervalSince(started),
            notes: notes
        ).redacted()
        await logger?.record(record)
        guard allowedExitCodes?.contains(output.exitCode) ?? true else {
            throw GitDomainError.commandFailed(
                command: record.commandLine,
                exitCode: output.exitCode,
                message: SecretRedactor.redact(output.stderr.isEmpty ? output.stdout : output.stderr)
            )
        }
        return output
    }

    private static func isBinary(_ data: Data) -> Bool {
        data.prefix(8000).contains(0) || String(data: data, encoding: .utf8) == nil
    }

    public func run(
        _ arguments: [String],
        kind: GitCommandKind,
        allowedExitCodes: Set<Int32>?,
        onProgress: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        try await run(arguments, environment: [:], notes: [], kind: kind, allowedExitCodes: allowedExitCodes, onProgress: onProgress)
    }

    public func run(
        _ arguments: [String],
        environment: [String: String],
        notes: [String],
        kind: GitCommandKind,
        allowedExitCodes: Set<Int32>?,
        onProgress: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        let started = Date()
        let directory = directory
        let cancellation = ProcessCancellation()
        let output = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                Self.queue.async {
                    continuation.resume(with: Result {
                        try ProcessRunner.stream(arguments, in: directory, cancellation: cancellation, environment: environment, onErrorLine: onProgress)
                    })
                }
            }
        } onCancel: {
            cancellation.cancel()
        }
        let record = GitCommandRecord(
            arguments: arguments,
            kind: kind,
            exitCode: output.exitCode,
            stdout: output.stdout,
            stderr: output.stderr,
            startedAt: started,
            duration: Date().timeIntervalSince(started),
            notes: notes
        ).redacted()
        await logger?.record(record)
        if cancellation.isCancelled { throw CancellationError() }
        guard allowedExitCodes?.contains(output.exitCode) ?? true else {
            throw GitDomainError.commandFailed(
                command: record.commandLine,
                exitCode: output.exitCode,
                message: SecretRedactor.redact(output.stderr.isEmpty ? output.stdout : output.stderr)
            )
        }
        return output.stdout
    }
}
