import MorkDomain
import Foundation

public final class ShellCommandRepositoryImpl: ShellCommandRepositoryProtocol {
    static let shell = "/bin/sh"
    private static let queue = DispatchQueue(label: "mork.shell", qos: .userInitiated, attributes: .concurrent)

    private let root: URL
    private let logger: GitCommandLogging?

    public init(root: URL, logger: GitCommandLogging?) {
        self.root = root
        self.logger = logger
    }

    public func run(script: String) async throws {
        let started = Date()
        let root = root
        let output = try await withCheckedThrowingContinuation { continuation in
            Self.queue.async {
                continuation.resume(with: Result { try Self.execute(script, in: root) })
            }
        }
        let record = GitCommandRecord(
            arguments: ["-c", script],
            kind: .write,
            exitCode: output.exitCode,
            stdout: output.text,
            stderr: "",
            startedAt: started,
            duration: Date().timeIntervalSince(started),
            program: GitCommandRecord.shell
        ).redacted()
        await logger?.record(record)
        guard output.exitCode == 0 else {
            throw GitDomainError.commandFailed(command: script, exitCode: output.exitCode, message: SecretRedactor.redact(output.text))
        }
    }

    private static func execute(_ script: String, in root: URL) throws -> (exitCode: Int32, text: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-c", script]
        process.currentDirectoryURL = root
        process.environment = ProcessRunner.environment()
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}
