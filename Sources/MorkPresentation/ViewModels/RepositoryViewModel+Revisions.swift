import MorkDomain
import Foundation

extension RepositoryViewModel {
    public var isDetachedHead: Bool { detachedHead != nil }
    public var hasRevisionOperation: Bool { repositoryState.revisionOperation != nil }

    public var headTitle: String {
        if let branch = currentBranch { return branch.name }
        return detachedHead.map { "Detached HEAD at \($0.shortHash)" } ?? ""
    }

    public func branchToCheckout(at commit: Commit) -> Branch? {
        let names = Set(commit.refNames.map { $0.hasPrefix(Self.headPointer) ? String($0.dropFirst(Self.headPointer.count)) : $0 })
        let tips = snapshot.branches.filter { !$0.isRemote && names.contains($0.name) }
        guard tips.count == 1, let branch = tips.first, !branch.isCurrent else { return nil }
        return branch
    }

    private static let headPointer = "HEAD -> "

    public func checkout(_ commit: Commit) async {
        await perform { try await $0.revisions.checkoutCommit.execute(commit: commit) }
    }

    @discardableResult
    public func createBranch(named name: String, at commit: Commit, checkout: Bool) async -> Bool {
        await perform { try await $0.revisions.createBranchAtCommit.execute(name: name, commit: commit, checkout: checkout) }
    }

    @discardableResult
    public func createTag(named name: String, message: String, at commit: Commit) async -> Bool {
        await perform { try await $0.revisions.createTagAtCommit.execute(name: name, message: message, commit: commit) }
    }

    @discardableResult
    public func createTag(named name: String, message: String, at target: TagTarget, pushToRemotes: Bool) async -> Bool {
        let created = switch target {
        case .head: await createTag(named: name, message: message)
        case let .branch(branch): await createTag(named: name, message: message, at: branch)
        case let .commit(commit): await createTag(named: name, message: message, at: commit)
        }
        let remoteNames = remotes.map(\.name)
        guard created, pushToRemotes, !remoteNames.isEmpty else { return created }
        return await perform { try await $0.remoteOptions.pushTag.execute(name: name, remotes: remoteNames) }
    }

    public func cherryPick(_ commit: Commit, options: CherryPickOptions = .standard) async {
        await perform { try await $0.revisions.cherryPickCommit.execute(commit: commit, options: options) }
    }

    public func revert(_ commit: Commit, options: RevertOptions = .standard) async {
        await perform { try await $0.revisions.revertCommit.execute(commit: commit, options: options) }
    }

    public func reset(to commit: Commit, mode: ResetMode) async {
        await perform { try await $0.revisions.resetCurrentBranch.execute(commit: commit, mode: mode) }
    }

    public func continueOperation() async {
        await perform { try await $0.revisions.continueOperation.execute() }
    }

    public func abortOperation() async {
        await perform { try await $0.revisions.abortOperation.execute() }
    }
}
