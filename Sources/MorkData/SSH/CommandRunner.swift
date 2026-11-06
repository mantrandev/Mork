import Foundation

public struct CommandOutput: Equatable, Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

public protocol CommandRunning: Sendable {
    func run(_ executable: String, _ arguments: [String], environment: [String: String]) async throws -> CommandOutput
}

public final class ProcessCommandRunner: CommandRunning {
    private static let queue = DispatchQueue(label: "mork.commands", qos: .userInitiated, attributes: .concurrent)

    public init() {}

    public func run(_ executable: String, _ arguments: [String], environment: [String: String]) async throws -> CommandOutput {
        try await withCheckedThrowingContinuation { continuation in
            Self.queue.async {
                continuation.resume(with: Result { try self.runSync(executable, arguments, environment: environment) })
            }
        }
    }

    func runSync(_ executable: String, _ arguments: [String], environment: [String: String] = [:]) throws -> CommandOutput {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error
        process.standardInput = FileHandle.nullDevice
        try process.run()
        let errorBuffer = CommandBuffer()
        let group = DispatchGroup()
        group.enter()
        let errorReader = Thread {
            errorBuffer.data = error.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        errorReader.qualityOfService = ProcessRunner.helperQuality(for: qos_class_self())
        errorReader.start()
        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        group.wait()
        process.waitUntilExit()
        return CommandOutput(
            exitCode: process.terminationStatus,
            stdout: String(decoding: outputData, as: UTF8.self),
            stderr: String(decoding: errorBuffer.data, as: UTF8.self)
        )
    }
}

private final class CommandBuffer: @unchecked Sendable {
    var data = Data()
}
