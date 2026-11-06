import Foundation

public enum PullMode: String, CaseIterable, Codable, Sendable {
    case merge
    case rebase
    case fastForwardOnly

    public static let `default` = PullMode.rebase

    public var arguments: [String] {
        switch self {
        case .merge: ["pull", "--no-rebase"]
        case .rebase: ["pull", "--rebase"]
        case .fastForwardOnly: ["pull", "--ff-only"]
        }
    }

    public var title: String {
        switch self {
        case .merge: "Merge"
        case .rebase: "Rebase"
        case .fastForwardOnly: "Fast-forward only"
        }
    }

    public var explanation: String {
        switch self {
        case .merge: "Fetch, then merge the remote branch. Creates a merge commit when both sides have new commits."
        case .rebase: "Fetch, then replay your local commits on top of the remote branch. Keeps history linear; your local commits get new hashes."
        case .fastForwardOnly: "Fetch, then move your branch forward only if you have no local commits. Refuses when the histories have diverged."
        }
    }
}

public struct PullOptions: Equatable, Sendable {
    public let remote: String
    public let branch: String
    public let rebase: Bool
    public let autostash: Bool

    public init(remote: String, branch: String, rebase: Bool, autostash: Bool) {
        self.remote = remote
        self.branch = branch
        self.rebase = rebase
        self.autostash = autostash
    }

    public var arguments: [String] {
        ["pull", rebase ? "--rebase" : "--no-rebase"] + (autostash ? ["--autostash"] : []) + [remote, branch]
    }
}

public struct PushOptions: Equatable, Sendable {
    public let remote: String
    public let branch: String
    public let setUpstream: Bool
    public let includeTags: Bool
    public let forceWithLease: Bool

    public init(remote: String, branch: String, setUpstream: Bool, includeTags: Bool, forceWithLease: Bool) {
        self.remote = remote
        self.branch = branch
        self.setUpstream = setUpstream
        self.includeTags = includeTags
        self.forceWithLease = forceWithLease
    }

    public init(branch: Branch, remote: String, includeTags: Bool, forceWithLease: Bool) {
        self.init(
            remote: remote,
            branch: branch.name,
            setUpstream: branch.upstream == nil || branch.isUpstreamGone,
            includeTags: includeTags,
            forceWithLease: forceWithLease
        )
    }

    public var arguments: [String] {
        ["push"]
            + (setUpstream ? ["--set-upstream"] : [])
            + (forceWithLease ? ["--force-with-lease"] : [])
            + (includeTags ? ["--tags"] : [])
            + [remote, branch]
    }
}
