import Foundation

public struct Submodule: Identifiable, Hashable, Sendable {
    public enum State: Sendable, Hashable {
        case current
        case notInitialized
        case outOfSync
        case conflict
    }

    public let name: String
    public let path: String
    public let url: String?
    public let commit: String
    public let state: State
    public let describe: String?
    public let isNested: Bool

    public init(name: String, path: String, url: String?, commit: String, state: State, describe: String?, isNested: Bool = false) {
        self.name = name
        self.path = path
        self.url = url
        self.commit = commit
        self.state = state
        self.describe = describe
        self.isNested = isNested
    }

    public var id: String { path }
    public var shortCommit: String { String(commit.prefix(7)) }
    public var isInitialized: Bool { state != .notInitialized }
}

public enum SubmoduleError: LocalizedError, Equatable, Sendable {
    case emptyURL
    case emptyPath
    case invalidPath(String)
    case notInitialized(String)

    public var errorDescription: String? {
        switch self {
        case .emptyURL:
            "Submodule URL cannot be empty."
        case .emptyPath:
            "Submodule path cannot be empty."
        case let .invalidPath(path):
            "\(path) must be a relative path inside this repository, without .. and not starting with -."
        case let .notInitialized(path):
            "Submodule \(path) is not initialized yet. Run Update Submodules first."
        }
    }
}
