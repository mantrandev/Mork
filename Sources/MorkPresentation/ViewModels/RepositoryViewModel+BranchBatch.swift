import MorkDomain
import Foundation

extension RepositoryViewModel {
    public func localBranches(in selections: Set<SidebarSelection>) -> [Branch] {
        let selected = localBranches.filter { selections.contains(.branch($0.name)) }
        return selected.count == selections.count ? selected : []
    }

    public func tags(in selections: Set<SidebarSelection>) -> [Tag] {
        let selected = tags.filter { selections.contains(.tag($0.name)) }
        return selected.count == selections.count ? selected : []
    }

    public func delete(tags: [Tag]) async {
        guard !tags.isEmpty else { return }
        await perform { dependencies in
            for tag in tags {
                try await dependencies.deleteTag.execute(tag: tag)
            }
        }
    }

    public func batchPushRemote(for branches: [Branch]) -> String? {
        let choices = Set(branches.compactMap { pushRemote(for: $0) })
        if choices.count == 1 { return choices.first }
        return remotes.first(where: { $0.name == "origin" })?.name ?? remotes.first?.name
    }

    @discardableResult
    public func fastForward(_ branches: [Branch]) async -> Bool {
        guard !branches.isEmpty, branches.allSatisfy(\.canFastForward) else { return false }
        return await performBranchBatch(branches, action: "Fast-forward") { dependencies, branch in
            try await dependencies.branchActions.fastForward.execute(branch: branch)
        }
    }

    @discardableResult
    public func push(_ branches: [Branch], to remote: String) async -> Bool {
        guard !branches.isEmpty, branches.allSatisfy({ !$0.isRemote }), remotes.contains(where: { $0.name == remote }) else { return false }
        return await performBranchBatch(branches, action: "Push") { dependencies, branch in
            try await dependencies.remoteOptions.pushWithOptions.execute(branch: branch, remote: remote, includeTags: false, forceWithLease: false)
        }
    }

    @discardableResult
    public func delete(_ branches: [Branch], force: Bool, alsoDeleteRemote: Bool) async -> Bool {
        guard !branches.isEmpty, branches.allSatisfy({ !$0.isRemote && !$0.isCurrent }) else { return false }
        let remoteTargets = Dictionary(uniqueKeysWithValues: branches.compactMap { branch in
            remoteBranchForDeletion(of: branch).map { (branch.fullName, $0) }
        })
        let serverTargets = alsoDeleteRemote
            ? Dictionary(remoteTargets.values.map { ($0.fullName, $0) }, uniquingKeysWith: { first, _ in first }).values.sorted { $0.fullName < $1.fullName }
            : []
        var deletedRemotes: Set<String> = []
        return await performBranchBatch(branches, action: "Delete", prepare: { dependencies in
            for remote in serverTargets {
                try await dependencies.workspace.remotes.deleteRemoteBranch.ensureDeletable(branch: remote)
            }
        }) { dependencies, branch in
            try await dependencies.deleteBranch.execute(branch: branch, force: force)
            if alsoDeleteRemote, let remote = remoteTargets[branch.fullName], !deletedRemotes.contains(remote.fullName) {
                do {
                    try await dependencies.workspace.remotes.deleteRemoteBranch.execute(branch: remote)
                    deletedRemotes.insert(remote.fullName)
                } catch {
                    throw NSError(domain: "BranchDeletion", code: 1, userInfo: [NSLocalizedDescriptionKey:
                        "The local branch '\(branch.name)' was deleted, but deleting '\(remote.name)' on the server failed: \(error.localizedDescription)"])
                }
            }
        }
    }

    private func performBranchBatch(
        _ branches: [Branch], action: String,
        prepare: (RepositoryDependencies) async throws -> Void = { _ in },
        operation: (RepositoryDependencies, Branch) async throws -> Void
    ) async -> Bool {
        await perform { dependencies in
            try await prepare(dependencies)
            for (index, branch) in branches.enumerated() {
                do {
                    try await operation(dependencies, branch)
                } catch {
                    throw NSError(domain: "BranchBatch", code: 1, userInfo: [NSLocalizedDescriptionKey:
                        "\(action) stopped at '\(branch.name)' after completing \(index) of \(branches.count) branches. \(error.localizedDescription)"])
                }
            }
        }
    }
}
