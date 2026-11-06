import Foundation

struct ProcessOutput: Sendable {
    let exitCode: Int32
    let stdoutData: Data
    let stderr: String

    var stdout: String { String(decoding: stdoutData, as: UTF8.self) }
}

enum ProcessRunner {
    static let environmentOverrides = [
        "GIT_TERMINAL_PROMPT": "0",
        "GIT_OPTIONAL_LOCKS": "0",
        "GIT_EDITOR": "true",
        "GIT_MERGE_AUTOEDIT": "no"
    ]

    static let configEntries = [
        ("core.quotePath", "false"),
        ("color.ui", "never")
    ]

    static let toolDirectories = ["/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]

    static func searchPath(_ inherited: String?) -> String {
        let current = (inherited ?? "").split(separator: ":").map(String.init).filter { !$0.isEmpty }
        return (current + toolDirectories.filter { !current.contains($0) }).joined(separator: ":")
    }

    static func environment(inheriting base: [String: String] = ProcessInfo.processInfo.environment, adding extra: [String: String] = [:]) -> [String: String] {
        var result = base.merging(environmentOverrides) { _, new in new }
        result["PATH"] = searchPath(base["PATH"])
        let inherited = Int(base["GIT_CONFIG_COUNT"] ?? "").map { max($0, 0) } ?? 0
        for (offset, entry) in configEntries.enumerated() {
            result["GIT_CONFIG_KEY_\(inherited + offset)"] = entry.0
            result["GIT_CONFIG_VALUE_\(inherited + offset)"] = entry.1
        }
        result["GIT_CONFIG_COUNT"] = String(inherited + configEntries.count)
        return result.merging(extra) { _, new in new }
    }

    static let launcher = URL(fileURLWithPath: "/usr/bin/env")
    static let git: URL = resolveGit()

    static func resolveGit() -> URL {
        let process = Process()
        process.executableURL = launcher
        process.arguments = ["git", "--exec-path"]
        process.environment = environment()
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return launcher }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let directory = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0, !directory.isEmpty else { return launcher }
        let candidate = URL(fileURLWithPath: directory).appendingPathComponent("git").resolvingSymlinksInPath()
        return FileManager.default.isExecutableFile(atPath: candidate.path) ? candidate : launcher
    }

    static func configure(_ process: Process, arguments: [String]) {
        process.executableURL = git
        process.arguments = git == launcher ? ["git"] + arguments : arguments
    }

    static func helperQuality(for caller: qos_class_t) -> QualityOfService {
        switch caller {
        case QOS_CLASS_USER_INTERACTIVE: .userInteractive
        case QOS_CLASS_USER_INITIATED: .userInitiated
        case QOS_CLASS_UTILITY: .utility
        case QOS_CLASS_BACKGROUND: .background
        default: .default
        }
    }

    static func run(_ arguments: [String], in directory: URL, input: Data? = nil, environment: [String: String] = [:], keepingOutputLines: Set<String>? = nil) throws -> ProcessOutput {
        let process = Process()
        configure(process, arguments: arguments)
        process.currentDirectoryURL = directory
        process.environment = Self.environment(adding: environment)

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error
        let inputPipe = input.map { _ in Pipe() }
        process.standardInput = inputPipe ?? FileHandle.nullDevice
        try process.run()

        let errorBuffer = DataBuffer()
        let group = DispatchGroup()
        let quality = helperQuality(for: qos_class_self())
        if let input, let writer = inputPipe?.fileHandleForWriting {
            _ = fcntl(writer.fileDescriptor, F_SETNOSIGPIPE, 1)
            group.enter()
            let inputWriter = Thread {
                try? writer.write(contentsOf: input)
                try? writer.close()
                group.leave()
            }
            inputWriter.qualityOfService = quality
            inputWriter.start()
        }
        group.enter()
        let errorReader = Thread {
            errorBuffer.data = error.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        errorReader.qualityOfService = quality
        errorReader.start()
        let outputData: Data
        if let keepingOutputLines {
            var retained = Set<String>()
            var splitter = GitLineSplitter()
            let handle = output.fileHandleForReading
            while case let chunk = handle.readData(ofLength: 16_384), !chunk.isEmpty {
                for line in splitter.feed(chunk) where keepingOutputLines.contains(line) {
                    retained.insert(line)
                }
            }
            for line in splitter.flush() where keepingOutputLines.contains(line) {
                retained.insert(line)
            }
            outputData = Data(retained.sorted().joined(separator: "\n").utf8)
        } else {
            outputData = output.fileHandleForReading.readDataToEndOfFile()
        }
        group.wait()
        process.waitUntilExit()

        return ProcessOutput(
            exitCode: process.terminationStatus,
            stdoutData: outputData,
            stderr: String(decoding: errorBuffer.data, as: UTF8.self)
        )
    }
}

private final class DataBuffer: @unchecked Sendable {
    var data = Data()
}
