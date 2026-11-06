import Foundation

public enum IntegrationLaunchBuilder {
    private static let open = "/usr/bin/open"
    private static let shell = "/bin/sh"

    public static func folder(_ app: DetectedIntegrationApp, path: String) -> ApplicationLaunch {
        guard case let .openArguments(arguments) = app.definition.folder else {
            return .open(paths: [path], application: app.application)
        }
        return .run(executable: open, arguments: ["-na", app.application, "--args"] + arguments + [path], environment: [:])
    }

    public static func file(_ app: DetectedIntegrationApp, path: String, line: Int?) -> ApplicationLaunch {
        let workspace = ApplicationLaunch.open(paths: [path], application: app.application)
        guard let line else { return workspace }
        if case let .openArguments(flag) = app.definition.line {
            return .run(executable: open, arguments: ["-na", app.application, "--args", flag, "\(line)", path], environment: [:])
        }
        guard let executable = app.executable else { return workspace }
        let arguments: [String]
        switch app.definition.line {
        case .none, .openArguments:
            return workspace
        case .goto:
            arguments = ["--goto", "\(path):\(line)"]
        case .colon:
            arguments = ["\(path):\(line)"]
        case let .flag(flag):
            arguments = [flag, "\(line)", path]
        case .plus:
            arguments = ["+\(line)", path]
        }
        return .run(executable: executable, arguments: arguments, environment: [:])
    }

    public static func custom(_ command: String, kind: IntegrationAppKind, path: String, line: Int?) -> ApplicationLaunch {
        let environment = switch kind {
        case .terminal: ["DIR": path]
        case .editor: ["FILE": path, "LINE": "\(line ?? 1)"]
        }
        return .run(executable: shell, arguments: ["-c", command], environment: environment)
    }
}
