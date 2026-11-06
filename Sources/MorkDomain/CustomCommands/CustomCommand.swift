import Foundation

public enum CustomCommandLocation: String, CaseIterable, Codable, Identifiable, Sendable {
    case repository
    case branch
    case commit
    case file
    case quickLaunch

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .repository: "Repository menu"
        case .branch: "Branch context menu"
        case .commit: "Commit context menu"
        case .file: "File context menu"
        case .quickLaunch: "Quick Launch"
        }
    }
}

public enum CustomCommandKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case git
    case shell

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .git: "Git command"
        case .shell: "Shell command"
        }
    }
}

public enum CustomCommandVariable: String, CaseIterable, Sendable {
    case repo
    case branch
    case sha
    case file
    case remote

    public var token: String { "${\(rawValue)}" }

    public var explanation: String {
        switch self {
        case .repo: "the repository root folder"
        case .branch: "the clicked branch, otherwise the current branch"
        case .sha: "the clicked commit, otherwise the selected commit"
        case .file: "the clicked file, relative to the repository root"
        case .remote: "the remote of the clicked remote branch, otherwise the current branch's upstream remote"
        }
    }
}

public struct CustomCommand: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var commandLine: String
    public var kind: CustomCommandKind
    public var locations: Set<CustomCommandLocation>
    public var confirmsBeforeRunning: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        commandLine: String,
        kind: CustomCommandKind = .git,
        locations: Set<CustomCommandLocation> = [.repository, .quickLaunch],
        confirmsBeforeRunning: Bool = false
    ) {
        self.id = id
        self.name = name
        self.commandLine = commandLine
        self.kind = kind
        self.locations = locations
        self.confirmsBeforeRunning = confirmsBeforeRunning
    }

    public func appears(in location: CustomCommandLocation) -> Bool {
        locations.contains(location)
    }

    public var problem: CustomCommandError? {
        let name = self.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return .emptyName }
        if commandLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .emptyCommand(name) }
        if locations.isEmpty { return .noLocation(name) }
        return nil
    }

    public var variables: [CustomCommandVariable] {
        CustomCommandVariable.allCases.filter { commandLine.contains($0.token) }
    }
}

public struct CustomCommandContext: Equatable, Sendable {
    public var repository: String
    public var branch: String?
    public var sha: String?
    public var file: String?
    public var remote: String?

    public init(repository: String, branch: String? = nil, sha: String? = nil, file: String? = nil, remote: String? = nil) {
        self.repository = repository
        self.branch = branch
        self.sha = sha
        self.file = file
        self.remote = remote
    }

    public func value(of variable: CustomCommandVariable) -> String? {
        switch variable {
        case .repo: repository
        case .branch: branch
        case .sha: sha
        case .file: file
        case .remote: remote
        }
    }
}

public enum CustomCommandInvocation: Equatable, Sendable {
    case git([String])
    case shell(String)

    public var displayLine: String {
        switch self {
        case let .git(arguments): (["git"] + arguments.map(ShellWords.quote)).joined(separator: " ")
        case let .shell(script): script
        }
    }
}

public enum CustomCommandError: LocalizedError, Equatable, Sendable {
    case emptyName
    case emptyCommand(String)
    case noLocation(String)
    case missingValue(CustomCommandVariable, command: String)

    public var errorDescription: String? {
        switch self {
        case .emptyName: "Give every custom command a name; it is the menu title."
        case let .emptyCommand(name): "\"\(name)\" has no command line."
        case let .noLocation(name): "\"\(name)\" appears nowhere. Pick at least one menu or Quick Launch."
        case let .missingValue(variable, command):
            "\"\(command)\" uses \(variable.token), but there is no \(variable.explanation) here. Run it from a menu that has one."
        }
    }
}
