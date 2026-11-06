import MorkDomain
import Foundation

extension RepositoryViewModel {
    public func remoteBranchForDeletion(of branch: Branch) -> Branch? {
        guard !branch.isRemote, !branch.isUpstreamGone, let upstream = branch.upstream else { return nil }
        return remoteBranches.first { candidate in
            candidate.name == upstream && remotes.contains { $0.name == candidate.remoteName }
        }
    }

    public func fastForwardTitle(for branch: Branch) -> String? {
        guard !branch.isRemote, let upstream = branch.upstream, !branch.isUpstreamGone else { return nil }
        return "Fast-Forward to '\(upstream)'"
    }

    public func fastForward(_ branch: Branch) async {
        await perform { try await $0.branchActions.fastForward.execute(branch: branch) }
    }

    public func pushRemote(for branch: Branch) -> String? {
        let names = remotes.map(\.name)
        guard !names.isEmpty else { return nil }
        return PushForm.defaultRemote(for: branch, in: names)
    }

    public func pullRequestRemote(for branch: Branch) -> Remote? {
        guard let name = pushRemote(for: branch), let remote = remotes.first(where: { $0.name == name }),
              CommitWebLink(remoteURL: remote.fetchURL) != nil else { return nil }
        return remote
    }

    public func pullRequestURL(for branch: Branch) async -> URL? {
        guard let remote = pullRequestRemote(for: branch) else { return nil }
        let remoteBranches = remoteBranches
        do {
            let load = dependencies.branchActions.loadPullRequestURL
            return try await reading { try await load.execute(branch: branch, remote: remote, remoteBranches: remoteBranches) }
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    public func canCheckoutAsWorktree(_ branch: Branch) -> Bool {
        guard !branch.isCurrent else { return false }
        let local = branch.isRemote ? branch.localName : branch.name
        guard localBranches.contains(where: { $0.name == local }) else { return branch.isRemote }
        return !worktrees.contains { $0.branch == local }
    }

    public func makeWorktreeForm(checkingOut branch: Branch) -> WorktreeForm {
        WorktreeForm(repository: url, branches: branches, worktrees: worktrees, checkingOut: branch)
    }

    public func canInteractivelyRebase(onto branch: Branch) -> Bool {
        !isDetachedHead && currentBranch != nil && currentBranch?.fullName != branch.fullName
    }

    @discardableResult
    public func createBranch(named name: String, from branch: Branch, checkout: Bool) async -> Bool {
        await perform { try await $0.branchActions.createBranch.execute(name: name, startPoint: branch, checkout: checkout) }
    }

    @discardableResult
    public func createTag(named name: String, message: String, at branch: Branch) async -> Bool {
        await perform { try await $0.branchActions.createTag.execute(name: name, message: message, branch: branch) }
    }

    public func makeRenameForm(for branch: Branch) -> RenameBranchForm {
        RenameBranchForm(branch: branch, localBranches: localBranches, remotes: remotes.map(\.name))
    }

    @discardableResult
    public func rename(_ form: RenameBranchForm) async -> Bool {
        let branch = form.branch
        let newName = form.trimmedName
        let existing = localBranches.map(\.name)
        let remote = form.remoteForRename
        let renamed = await perform { try await $0.branchActions.rename.execute(branch: branch, newName: newName, existingNames: existing, alsoOnRemote: remote) }
        if renamed { followRename(of: branch, to: newName) }
        return renamed
    }

    public func upstreamChoices(for branch: Branch) -> UpstreamChoices {
        UpstreamChoices(branch: branch, remoteBranches: remoteBranches)
    }

    public func setUpstream(of branch: Branch, to upstream: Branch) async {
        await perform { try await $0.workspace.remotes.setUpstream.execute(upstream: upstream, branch: branch) }
    }

    private func followRename(of branch: Branch, to newName: String) {
        let renamed = historyOptions.renamingBranch(branch.fullName, to: "refs/heads/\(newName)")
        if renamed != historyOptions { saveHistoryOptions(renamed) }
        if sidebarItem == .branch(branch.name) { sidebarItem = .branch(newName) }
    }
}
