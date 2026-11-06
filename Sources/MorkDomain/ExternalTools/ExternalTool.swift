import Foundation

public enum ExternalToolRole: String, CaseIterable, Sendable {
    case merge
    case diff

    public var title: String {
        switch self {
        case .merge: "merge tool"
        case .diff: "diff tool"
        }
    }

    public var requiredPlaceholders: [String] {
        switch self {
        case .merge: ["MERGED"]
        case .diff: ["LOCAL", "REMOTE"]
        }
    }
}

public struct ExternalToolBundle: Hashable, Sendable {
    public let name: String
    public let identifiers: [String]
    public let executable: String

    public init(name: String, identifiers: [String], executable: String) {
        self.name = name
        self.identifiers = identifiers
        self.executable = executable
    }
}

public struct ExternalToolDefinition: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let bundles: [ExternalToolBundle]
    public let commands: [String]
    public let mergeArguments: String?
    public let diffArguments: String?

    public init(id: String, name: String, bundles: [ExternalToolBundle], commands: [String], mergeArguments: String? = nil, diffArguments: String? = nil) {
        self.id = id
        self.name = name
        self.bundles = bundles
        self.commands = commands
        self.mergeArguments = mergeArguments
        self.diffArguments = diffArguments
    }

    public var hasGitBackend: Bool { mergeArguments == nil && diffArguments == nil }

    public func arguments(for role: ExternalToolRole) -> String? {
        switch role {
        case .merge: mergeArguments
        case .diff: diffArguments
        }
    }
}

public struct DetectedExternalTool: Identifiable, Hashable, Sendable {
    public let definition: ExternalToolDefinition
    public let executable: String

    public init(definition: ExternalToolDefinition, executable: String) {
        self.definition = definition
        self.executable = executable
    }

    public var id: String { definition.id }
    public var name: String { definition.name }
}

public enum ExternalToolLaunch: Equatable, Sendable {
    case backend(tool: String, path: String)
    case command(tool: String, command: String)

    public var tool: String {
        switch self {
        case let .backend(tool, _), let .command(tool, _): tool
        }
    }
}

public enum ExternalDiffTarget: Equatable, Sendable {
    case unstaged
    case staged
    case commit(Commit)

    public var isRootCommit: Bool {
        guard case let .commit(commit) = self else { return false }
        return commit.parents.isEmpty
    }

    public func revisions(emptyTree: String) -> [String] {
        switch self {
        case .unstaged:
            []
        case .staged:
            ["--cached"]
        case let .commit(commit):
            switch commit.parents.count {
            case 0: [emptyTree, commit.hash]
            case 1: ["\(commit.hash)^!"]
            default: [commit.parents[0], commit.hash]
            }
        }
    }
}

public struct ExternalToolExit: Equatable, Sendable {
    public let exitCode: Int32
    public let output: String

    public init(exitCode: Int32, output: String) {
        self.exitCode = exitCode
        self.output = output
    }
}

public enum MergeToolOutcome: Equatable, Sendable {
    case resolved
    case unresolved(String)
}

public struct ExternalToolCheck: Equatable, Sendable {
    public let isReady: Bool
    public let message: String
    public let command: String?

    public init(isReady: Bool, message: String, command: String?) {
        self.isReady = isReady
        self.message = message
        self.command = command
    }
}

public enum ExternalToolError: LocalizedError, Equatable, Sendable {
    case notConfigured(ExternalToolRole)
    case emptyCommand(ExternalToolRole)
    case missingPlaceholders(ExternalToolRole, [String])
    case commandNotFound(String)
    case toolNotFound(String)
    case unsupportedConflict(ConflictKind)
    case diffFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .notConfigured(role):
            "No \(role.title) is set. Pick one in Settings ▸ Merge & Diff."
        case let .emptyCommand(role):
            "The custom \(role.title) command is empty. Enter it in Settings ▸ Merge & Diff."
        case let .missingPlaceholders(role, names):
            "The custom \(role.title) command must use \(names.map { "$\($0)" }.joined(separator: " and ")). Git replaces them with the file paths when it runs the tool."
        case let .commandNotFound(program):
            "\(program) was not found. Use the full path to the program, or check that it is installed."
        case let .toolNotFound(name):
            "\(name) was not found. It may have been moved or uninstalled. Rescan in Settings ▸ Merge & Diff, or pick another tool."
        case let .unsupportedConflict(kind):
            "This file is \(kind.title.lowercased()) (\(kind.statusCode)). git mergetool would ask on the keyboard whether to keep the modified or the deleted file, which Mork cannot answer for it. Use Keep File or Delete File instead."
        case let .diffFailed(output):
            output.isEmpty ? "The diff tool failed." : output
        }
    }
}
