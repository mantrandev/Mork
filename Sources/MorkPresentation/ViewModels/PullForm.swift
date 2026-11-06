import MorkDomain
import Foundation

public struct PullForm: Equatable, Sendable {
    public let remotes: [String]
    public let into: String?
    public var remote: String
    public var branchName: String
    public private(set) var branches: [String]
    public var rebase: Bool
    public var autostash: Bool
    private let remoteBranches: [Branch]
    private let preferredName: String?

    public init(current: Branch?, remotes: [String], remoteBranches: [Branch], rebase: Bool, autostash: Bool) {
        self.remotes = remotes
        self.remoteBranches = remoteBranches
        self.rebase = rebase
        self.autostash = autostash
        into = current?.name
        remote = PushForm.defaultRemote(for: current, in: remotes)
        branches = Self.branches(of: remoteBranches, on: remote)
        let upstream = current?.upstream.flatMap { name in remoteBranches.first { $0.name == name } }
        preferredName = upstream?.remoteName == remote ? upstream?.localName : current?.name
        branchName = ""
        branchName = defaultBranch()
    }

    private static func branches(of remoteBranches: [Branch], on remote: String) -> [String] {
        remoteBranches.filter { $0.remoteName == remote && $0.localName != "HEAD" }.map(\.localName)
    }

    public var options: PullOptions? {
        guard into != nil, remotes.contains(remote), branches.contains(branchName) else { return nil }
        return PullOptions(remote: remote, branch: branchName, rebase: rebase, autostash: autostash)
    }

    public mutating func select(remote: String) {
        self.remote = remote
        branches = Self.branches(of: remoteBranches, on: remote)
        branchName = branches.contains(branchName) ? branchName : defaultBranch()
    }

    private func defaultBranch() -> String {
        let names = branches
        if let preferredName, names.contains(preferredName) { return preferredName }
        return names.first ?? ""
    }
}
