import Foundation

public protocol LoadPullRequestURLUseCaseProtocol: Sendable {
    func execute(branch: Branch, remote: Remote, remoteBranches: [Branch]) async throws -> URL
}

public final class LoadPullRequestURLUseCase: LoadPullRequestURLUseCaseProtocol {
    private static let commonDefaults = ["main", "master"]

    private let branches: BranchActionsRepositoryProtocol

    public init(branches: BranchActionsRepositoryProtocol) {
        self.branches = branches
    }

    public func execute(branch: Branch, remote: Remote, remoteBranches: [Branch]) async throws -> URL {
        guard let link = CommitWebLink(remoteURL: remote.fetchURL) else { throw BranchActionError.noHostedRemote(remote.name) }
        let source = Self.sourceName(of: branch, on: remote.name)
        let onRemote = Set(remoteBranches.filter { $0.remoteName == remote.name }.map(\.localName))
        let base = try await branches.defaultBranch(ofRemote: remote.name) ?? Self.commonDefaults.first(where: onRemote.contains)
        guard let url = link.pullRequestURL(branch: source, base: base == source ? nil : base) else {
            throw BranchActionError.noHostedRemote(remote.name)
        }
        return url
    }

    private static func sourceName(of branch: Branch, on remote: String) -> String {
        let prefix = remote + "/"
        guard let upstream = branch.upstream, upstream.hasPrefix(prefix), upstream.count > prefix.count else { return branch.name }
        return String(upstream.dropFirst(prefix.count))
    }
}
