import Foundation

public struct Remote: Identifiable, Hashable, Sendable {
    public let name: String
    public let fetchURL: String
    public let pushURL: String?

    public init(name: String, fetchURL: String, pushURL: String? = nil) {
        self.name = name
        self.fetchURL = fetchURL
        self.pushURL = pushURL
    }

    public var id: String { name }
    public var effectivePushURL: String { pushURL ?? fetchURL }
}

public struct RemoteEdit: Equatable, Sendable {
    public var name: String
    public var fetchURL: String
    public var pushURL: String

    public init(name: String, fetchURL: String, pushURL: String) {
        self.name = name
        self.fetchURL = fetchURL
        self.pushURL = pushURL
    }

    public init(remote: Remote) {
        self.init(name: remote.name, fetchURL: remote.fetchURL, pushURL: remote.pushURL ?? "")
    }
}

public enum RemoteValidationError: LocalizedError, Equatable, Sendable {
    case emptyName
    case invalidName(String, reason: String)
    case duplicateName(String)
    case emptyURL
    case notRemoteBranch(String)
    case defaultRemoteBranch(String)

    public var errorDescription: String? {
        switch self {
        case .emptyName:
            "Remote name cannot be empty."
        case let .invalidName(name, reason):
            "\"\(name)\" is not a valid remote name: \(reason)."
        case let .duplicateName(name):
            "A remote named \"\(name)\" already exists."
        case .emptyURL:
            "Remote URL cannot be empty."
        case let .notRemoteBranch(name):
            "\(name) is a local branch, not a remote branch."
        case let .defaultRemoteBranch(name):
            "\(name) is the default branch of its remote. Pick another default branch on the server before deleting it."
        }
    }
}

public struct RemoteRemovalImpact: Equatable, Sendable {
    public let remote: String
    public let remoteBranches: [String]
    public let trackingBranches: [String]

    public var message: String {
        var lines: [String] = []
        if remoteBranches.isEmpty {
            lines.append("\(remote) has no remote-tracking branches.")
        } else {
            let count = remoteBranches.count
            lines.append("Its \(count) remote-tracking branch\(count == 1 ? "" : "es") (refs/remotes/\(remote)/…) go away. The branches on the server are not touched.")
        }
        if !trackingBranches.isEmpty {
            lines.append("Local branches that lose their upstream: \(trackingBranches.joined(separator: ", ")).")
        }
        return lines.joined(separator: "\n")
    }
}

extension RepositorySnapshot {
    public func remoteBranches(of remoteName: String) -> [Branch] {
        remoteBranches.filter { $0.remoteName == remoteName }
    }

    public func removalImpact(of remote: Remote) -> RemoteRemovalImpact {
        let prefix = remote.name + "/"
        return RemoteRemovalImpact(
            remote: remote.name,
            remoteBranches: remoteBranches(of: remote.name).map(\.name).sorted(),
            trackingBranches: localBranches.filter { $0.upstream?.hasPrefix(prefix) == true }.map(\.name).sorted()
        )
    }
}
