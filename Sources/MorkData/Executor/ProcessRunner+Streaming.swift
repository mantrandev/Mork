import Foundation

final class ProcessCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    var isCancelled: Bool { lock.withLock { cancelled } }

    func attach(_ process: Process) -> Bool {
        lock.withLock {
            self.process = process
            return !cancelled
        }
    }

    func cancel() {
        let running = lock.withLock { () -> Process? in
            cancelled = true
            return process
        }
        if let running, running.isRunning { running.terminate() }
    }
}

extension ProcessRunner {
    static func stream(
        _ arguments: [String],
        in directory: URL,
        cancellation: ProcessCancellation,
        environment extra: [String: String] = [:],
        onErrorLine: @escaping @Sendable (String) -> Void
    ) throws -> ProcessOutput {
        guard !cancellation.isCancelled else { throw CancellationError() }
        let process = Process()
        configure(process, arguments: arguments)
        process.currentDirectoryURL = directory
        process.environment = environment(adding: extra)

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error
        process.standardInput = FileHandle.nullDevice
        try process.run()
        if !cancellation.attach(process) { process.terminate() }

        let errorBuffer = StreamBuffer()
        let group = DispatchGroup()
        group.enter()
        let errorReader = Thread {
            var splitter = GitLineSplitter()
            let handle = error.fileHandleForReading
            while case let chunk = handle.availableData, !chunk.isEmpty {
                errorBuffer.data.append(chunk)
                splitter.feed(chunk).forEach(onErrorLine)
            }
            splitter.flush().forEach(onErrorLine)
            group.leave()
        }
        errorReader.qualityOfService = helperQuality(for: qos_class_self())
        errorReader.start()
        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        group.wait()
        process.waitUntilExit()

        return ProcessOutput(
            exitCode: process.terminationStatus,
            stdoutData: outputData,
            stderr: String(decoding: errorBuffer.data, as: UTF8.self)
        )
    }
}

private final class StreamBuffer: @unchecked Sendable {
    var data = Data()
}
