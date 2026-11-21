import MorkDomain
import Foundation

public final class ProcessGitCommandExecutor: GitCommandExecuting {
    public static let recordedOutputLimit = 65_536
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

    public func runData(_ arguments: [String], kind: GitCommandKind, allowedExitCodes: Set<Int32>?, byteLimit: Int) async throws -> Data {
        try await execute(arguments, input: nil, environment: [:], kind: kind, allowedExitCodes: allowedExitCodes, summarizesBinary: true, outputLimit: byteLimit).stdoutData
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
        keepingOutputLines: Set<String>? = nil,
        outputLimit: Int? = nil
    ) async throws -> ProcessOutput {
        let started = Date()
        let directory = directory
        let output = try await withCheckedThrowingContinuation { continuation in
            Self.queue.async {
                continuation.resume(with: Result {
                    try ProcessRunner.run(arguments, in: directory, input: input.map(LosslessText.encode), environment: environment, keepingOutputLines: keepingOutputLines, outputLimit: outputLimit)
                })
            }
        }
        let record = GitCommandRecord(
            arguments: arguments,
            kind: kind,
            exitCode: output.exitCode,
            stdout: Self.recordedOutput(output.stdoutData, summarizesBinary: summarizesBinary),
            stderr: output.stderr,
            startedAt: started,
            duration: Date().timeIntervalSince(started),
            notes: notes
        ).redacted()
        await logger?.record(record)
        if output.isTruncated, let outputLimit { throw GitDomainError.outputTooLarge(limit: outputLimit) }
        guard allowedExitCodes?.contains(output.exitCode) ?? true else {
            throw GitDomainError.commandFailed(
                command: record.commandLine,
                exitCode: output.exitCode,
                message: output.stderr.isEmpty ? record.stdout : SecretRedactor.redact(output.stderr)
            )
        }
        return output
    }

    static func recordedOutput(_ data: Data, summarizesBinary: Bool) -> String {
        let prefix = utf8Prefix(of: data, maxBytes: recordedOutputLimit)
        if summarizesBinary, data.prefix(8000).contains(0) || String(data: prefix, encoding: .utf8) == nil {
            return "Binary output, \(data.count) bytes"
        }
        return String(decoding: prefix, as: UTF8.self)
    }

    static func utf8Prefix(of data: Data, maxBytes: Int) -> Data {
        guard data.count > maxBytes else { return data }
        var end = data.startIndex + maxBytes
        var steps = 0
        while steps < 3, end > data.startIndex, data[end] & 0xC0 == 0x80 {
            end -= 1
            steps += 1
        }
        return data[data.startIndex..<end]
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
