import Foundation

public enum IntegrationAppKind: String, CaseIterable, Sendable {
    case terminal
    case editor

    public var title: String {
        switch self {
        case .terminal: "terminal app"
        case .editor: "external editor"
        }
    }

    public var placeholder: String {
        switch self {
        case .terminal: "DIR"
        case .editor: "FILE"
        }
    }
}

public enum EditorLineStyle: Hashable, Sendable {
    case none
    case goto
    case colon
    case flag(String)
    case plus
    case openArguments(String)
}

public enum TerminalFolderStyle: Hashable, Sendable {
    case workspace
    case openArguments([String])
}

public struct IntegrationAppDefinition: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let kind: IntegrationAppKind
    public let bundles: [ExternalToolBundle]
    public let commands: [String]
    public let line: EditorLineStyle
    public let folder: TerminalFolderStyle

    public init(
        id: String,
        name: String,
        kind: IntegrationAppKind,
        bundles: [ExternalToolBundle],
        commands: [String] = [],
        line: EditorLineStyle = .none,
        folder: TerminalFolderStyle = .workspace
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.bundles = bundles
        self.commands = commands
        self.line = line
        self.folder = folder
    }
}

public struct DetectedIntegrationApp: Identifiable, Hashable, Sendable {
    public let definition: IntegrationAppDefinition
    public let application: String
    public let executable: String?

    public init(definition: IntegrationAppDefinition, application: String, executable: String?) {
        self.definition = definition
        self.application = application
        self.executable = executable
    }

    public var id: String { definition.id }
    public var name: String { definition.name }
    public var kind: IntegrationAppKind { definition.kind }
}

public struct IntegrationInventory: Equatable, Sendable {
    public static let empty = IntegrationInventory(tools: [], apps: [])

    public let tools: [DetectedExternalTool]
    public let apps: [DetectedIntegrationApp]

    public init(tools: [DetectedExternalTool], apps: [DetectedIntegrationApp]) {
        self.tools = tools
        self.apps = apps
    }

    public func apps(_ kind: IntegrationAppKind) -> [DetectedIntegrationApp] {
        apps.filter { $0.kind == kind }
    }
}

public enum ApplicationLaunch: Equatable, Sendable {
    case open(paths: [String], application: String)
    case run(executable: String, arguments: [String], environment: [String: String])
}

public struct IntegrationSettings: Codable, Hashable, Sendable {
    public var terminal: String?
    public var editor: String?
    public var customTerminalCommand: String
    public var customEditorCommand: String

    public init(terminal: String? = nil, editor: String? = nil, customTerminalCommand: String = "", customEditorCommand: String = "") {
        self.terminal = terminal
        self.editor = editor
        self.customTerminalCommand = customTerminalCommand
        self.customEditorCommand = customEditorCommand
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func value(_ key: CodingKeys) -> String? {
            (try? container.decodeIfPresent(String.self, forKey: key)) ?? nil
        }
        self.init(
            terminal: value(.terminal),
            editor: value(.editor),
            customTerminalCommand: value(.customTerminalCommand) ?? "",
            customEditorCommand: value(.customEditorCommand) ?? ""
        )
    }

    public func selection(for kind: IntegrationAppKind) -> String? {
        switch kind {
        case .terminal: terminal ?? IntegrationAppCatalog.defaultTerminalID
        case .editor: editor
        }
    }

    public func customCommand(for kind: IntegrationAppKind) -> String {
        switch kind {
        case .terminal: customTerminalCommand
        case .editor: customEditorCommand
        }
    }
}

public enum IntegrationError: LocalizedError, Equatable, Sendable {
    case notConfigured(IntegrationAppKind)
    case appNotFound(String)
    case emptyCommand(IntegrationAppKind)
    case missingPlaceholder(IntegrationAppKind)
    case commandNotFound(String)

    public var errorDescription: String? {
        switch self {
        case let .notConfigured(kind):
            "No \(kind.title) is set. Pick one in Settings ▸ Integration."
        case let .appNotFound(name):
            "\(name) was not found. It may have been moved or uninstalled. Rescan in Settings ▸ Integration, or pick another app."
        case let .emptyCommand(kind):
            "The custom \(kind.title) command is empty. Enter it in Settings ▸ Integration."
        case let .missingPlaceholder(kind):
            "The custom \(kind.title) command must use $\(kind.placeholder). Mork replaces it with the path to open."
        case let .commandNotFound(program):
            "\(program) was not found. Use the full path to the program, or check that it is installed."
        }
    }
}
