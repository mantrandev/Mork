import Foundation

public enum BranchActionError: LocalizedError, Equatable, Sendable {
    case noUpstream(String)
    case notFastForward(branch: String, upstream: String)
    case noHostedRemote(String)
    case remoteBranchRename(String)

    public var errorDescription: String? {
        switch self {
        case let .noUpstream(branch):
            "\(branch) has no upstream branch to fast-forward to. Set one in Tracking first."
        case let .notFastForward(branch, upstream):
            "\(branch) has commits that \(upstream) does not have, so it cannot be fast-forwarded. Merge or rebase it instead."
        case let .noHostedRemote(remote):
            "\(remote) is not on GitHub, GitLab, Bitbucket or Gitea, so Mork cannot open a pull request page for it."
        case let .remoteBranchRename(branch):
            "\(branch) is a remote-tracking branch. Rename the local branch and use \"Also rename on the remote\" instead."
        }
    }
}

extension Branch {
    public var canFastForward: Bool {
        !isRemote && upstream != nil && !isUpstreamGone && behind > 0 && ahead == 0
    }
}

public struct UpstreamChoices: Equatable, Sendable {
    public struct Group: Identifiable, Equatable, Sendable {
        public let remote: String
        public let branches: [Branch]

        public var id: String { remote }
    }

    public let matching: [Branch]
    public let groups: [Group]

    public init(branch: Branch, remoteBranches: [Branch]) {
        let remote = remoteBranches.filter(\.isRemote)
        let matching = remote.filter { $0.localName == branch.name }
        let matchingNames = Set(matching.map(\.fullName))
        var order: [String] = []
        var members: [String: [Branch]] = [:]
        for candidate in remote where !matchingNames.contains(candidate.fullName) {
            guard let name = candidate.remoteName else { continue }
            if members[name] == nil { order.append(name) }
            members[name, default: []].append(candidate)
        }
        self.matching = matching
        groups = order.map { Group(remote: $0, branches: members[$0] ?? []) }
    }

    public var isEmpty: Bool { matching.isEmpty && groups.isEmpty }
}
