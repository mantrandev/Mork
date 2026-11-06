import MorkDomain
import Foundation

public struct PushForm: Equatable, Sendable {
    private static let preferredRemote = "origin"
    static let addRemoteHint = "git remote add origin <url>"

    public let branches: [Branch]
    public let remotes: [String]
    public var remote: String
    public var branchName: String
    public var includeTags = false
    public var forceWithLease = false

    public init(branches: [Branch], remotes: [String], selecting selectedName: String? = nil) {
        let local = branches.filter { !$0.isRemote }
        let selected = local.first { $0.name == selectedName } ?? local.first(where: \.isCurrent) ?? local.first
        self.branches = local
        self.remotes = remotes
        branchName = selected?.name ?? ""
        remote = Self.defaultRemote(for: selected, in: remotes)
    }

    public var branch: Branch? { branches.first { $0.name == branchName } }

    public var options: PushOptions? {
        guard let branch, remotes.contains(remote) else { return nil }
        return PushOptions(branch: branch, remote: remote, includeTags: includeTags, forceWithLease: forceWithLease)
    }

    public var canPush: Bool { options != nil }

    public var command: String {
        guard !remotes.isEmpty else { return Self.addRemoteHint }
        return options.map { (["git"] + $0.arguments).map(ShellWords.quote).joined(separator: " ") } ?? ""
    }

    public func destinationTitle(for remote: String) -> String {
        let target = "\(remote)/\(branchName)"
        return branch?.upstream == target && branch?.isUpstreamGone == false ? "default (\(target))" : target
    }

    public static func defaultRemote(for branch: Branch?, in remotes: [String]) -> String {
        if let upstream = branch?.upstream,
           let tracked = remotes.filter({ upstream.hasPrefix($0 + "/") }).max(by: { $0.count < $1.count }) {
            return tracked
        }
        if remotes.contains(preferredRemote) { return preferredRemote }
        return remotes.first ?? ""
    }
}
