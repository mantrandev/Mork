import Darwin
import Foundation

enum ProcessTree {
    static func descendants(of pid: pid_t) -> [pid_t] {
        var result: [pid_t] = []
        var pending = [pid]
        while let parent = pending.popLast() {
            var children = [pid_t](repeating: 0, count: 256)
            let count = proc_listchildpids(parent, &children, Int32(children.count * MemoryLayout<pid_t>.size))
            let found = children.prefix(Int(max(count, 0))).filter { $0 > 0 }
            result.append(contentsOf: found)
            pending.append(contentsOf: found)
        }
        return result
    }

    @discardableResult
    static func terminate(_ pid: pid_t) -> [pid_t] {
        let tree = [pid] + descendants(of: pid)
        tree.forEach { kill($0, SIGTERM) }
        return tree
    }

    static func waitForExit(_ pids: [pid_t], timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        var alive = pids.filter { kill($0, 0) == 0 }
        while !alive.isEmpty, Date() < deadline {
            usleep(20_000)
            alive = alive.filter { kill($0, 0) == 0 }
        }
        alive.forEach { kill($0, SIGKILL) }
    }
}

final class ProcessTreeCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false
    private var terminated: [pid_t] = []

    var isCancelled: Bool { lock.withLock { cancelled } }
    var terminatedProcesses: [pid_t] { lock.withLock { terminated } }

    func attach(_ process: Process) -> Bool {
        lock.withLock {
            self.process = process
            return !cancelled
        }
    }

    func cancel() {
        lock.withLock {
            cancelled = true
            guard let process, process.isRunning else { return }
            terminated = ProcessTree.terminate(process.processIdentifier)
        }
    }
}

extension ProcessRunner {
    static func runTool(
        _ arguments: [String],
        in directory: URL,
        cancellation: ProcessTreeCancellation,
        drainTimeout: DispatchTimeInterval = .seconds(2)
    ) throws -> ProcessOutput {
        guard !cancellation.isCancelled else { throw CancellationError() }
        let process = Process()
        configure(process, arguments: arguments)
        process.currentDirectoryURL = directory
        process.environment = environment()

        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        process.standardInput = FileHandle.nullDevice
        try process.run()
        if !cancellation.attach(process) { ProcessTree.terminate(process.processIdentifier) }

        let buffer = ToolOutputBuffer()
        let drained = DispatchSemaphore(value: 0)
        let outputReader = Thread {
            let handle = output.fileHandleForReading
            while case let chunk = handle.availableData, !chunk.isEmpty {
                buffer.append(chunk)
            }
            drained.signal()
        }
        outputReader.qualityOfService = helperQuality(for: qos_class_self())
        outputReader.start()
        process.waitUntilExit()
        if cancellation.isCancelled { ProcessTree.waitForExit(cancellation.terminatedProcesses, timeout: 2) }
        _ = drained.wait(timeout: .now() + drainTimeout)

        return ProcessOutput(exitCode: process.terminationStatus, stdoutData: buffer.data, stderr: "")
    }
}

private final class ToolOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    var data: Data { lock.withLock { storage } }

    func append(_ chunk: Data) {
        lock.withLock { storage.append(chunk) }
    }
}
