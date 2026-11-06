import MorkDomain
import Foundation

extension RepositoryViewModel {
    public func removalMessage(for remote: Remote) -> String {
        snapshot.removalImpact(of: remote).message
    }

    public func setUpstreamTitle(for branch: Branch) -> String {
        "Set as Upstream of \(currentBranch?.name ?? "HEAD")"
    }

    public func isUpstreamOfCurrentBranch(_ branch: Branch) -> Bool {
        currentBranch?.upstream == branch.name
    }

    @discardableResult
    public func addRemote(name: String, url: String, fetch: Bool) async -> Bool {
        await perform { try await $0.workspace.remotes.addRemote.execute(name: name, url: url, fetch: fetch) }
    }

    @discardableResult
    public func editRemote(_ remote: Remote, edit: RemoteEdit) async -> Bool {
        await perform { try await $0.workspace.remotes.editRemote.execute(remote: remote, edit: edit) }
    }

    public func removeRemote(_ remote: Remote) async {
        await perform { try await $0.workspace.remotes.removeRemote.execute(remote: remote) }
    }

    public func fetchRemote(_ remote: Remote) async {
        await perform { try await $0.workspace.remotes.fetchRemote.execute(remote: remote) }
    }

    public func pruneRemote(_ remote: Remote) async {
        await perform { try await $0.workspace.remotes.pruneRemote.execute(remote: remote) }
    }

    public func deleteRemoteBranch(_ branch: Branch) async {
        await perform { try await $0.workspace.remotes.deleteRemoteBranch.execute(branch: branch) }
    }

    public func setUpstream(_ upstream: Branch) async {
        let current = currentBranch
        await perform { try await $0.workspace.remotes.setUpstream.execute(upstream: upstream, branch: current) }
    }

    public func unsetUpstream(_ branch: Branch) async {
        await perform { try await $0.workspace.remotes.unsetUpstream.execute(branch: branch) }
    }
}
