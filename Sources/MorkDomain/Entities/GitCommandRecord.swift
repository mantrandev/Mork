import Foundation

public enum GitCommandKind: Sendable, Equatable {
    case read
    case write
}

public struct GitCommandRecord: Identifiable, Sendable, Equatable {
    public static let git = "git"
    public static let shell = "sh"

    public let id: UUID
    public let program: String
    public let arguments: [String]
    public let kind: GitCommandKind
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String
    public let startedAt: Date
    public let duration: TimeInterval
    public let notes: [String]

    public init(
        id: UUID = UUID(),
        arguments: [String],
        kind: GitCommandKind,
        exitCode: Int32,
        stdout: String,
        stderr: String,
        startedAt: Date,
        duration: TimeInterval,
        notes: [String] = [],
        program: String = GitCommandRecord.git
    ) {
        self.id = id
        self.program = program
        self.arguments = arguments
        self.kind = kind
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.startedAt = startedAt
        self.duration = duration
        self.notes = notes
    }

    public var succeeded: Bool { exitCode == 0 || conflictCount != nil }

    public var conflictCount: Int? {
        guard program == Self.git, arguments.first == "merge-file", (1...127).contains(exitCode) else { return nil }
        return Int(exitCode)
    }

    public var exitSummary: String {
        guard let conflictCount else { return "exit \(exitCode)" }
        return conflictCount == 1 ? "1 conflict" : "\(conflictCount) conflicts"
    }

    public func limitingOutput(to limit: Int) -> GitCommandRecord {
        guard stdout.utf8.count > limit || stderr.utf8.count > limit else { return self }
        return GitCommandRecord(
            id: id,
            arguments: arguments,
            kind: kind,
            exitCode: exitCode,
            stdout: String(stdout.prefix(limit + 1)),
            stderr: String(stderr.prefix(limit + 1)),
            startedAt: startedAt,
            duration: duration,
            program: program
        )
    }
    public var isShell: Bool { program == Self.shell }
    public var commandLine: String {
        if isShell, arguments.count == 2, arguments[0] == "-c" { return arguments[1] }
        return ([program] + arguments.map(ShellWords.quote)).joined(separator: " ")
    }
}
