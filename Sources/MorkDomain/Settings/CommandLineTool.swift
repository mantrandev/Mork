import Foundation

public enum CommandLineToolStatus: Equatable, Sendable {
    case unavailable
    case notInstalled(name: String)
    case installed(name: String, path: String, needsPathEntry: Bool)
}

public enum CommandLineToolError: Error, Equatable, LocalizedError {
    case unavailable
    case occupied(path: String)
    case notWritable

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            "The command line tool ships inside Mork.app. Build the app with scripts/build-app.sh and open it from Applications."
        case let .occupied(path):
            "\(path) is another program, so Mork left it alone. Remove or rename it, then install again."
        case .notWritable:
            "No folder for commands could be written. Make ~/.local/bin writable and try again."
        }
    }
}
