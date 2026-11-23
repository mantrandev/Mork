import MorkDomain

extension RepositoryViewModel {
    public func isMergeCollapsed(_ commit: Commit) -> Bool {
        collapsedMerges.contains(commit.hash)
    }

    public func toggleMergeCollapse(_ commit: Commit) async {
        guard commit.isMerge else { return }
        if collapsedMerges.remove(commit.hash) == nil { collapsedMerges.insert(commit.hash) }
        await present(presentation.snapshot)
        if selectedCommitHashes.contains(where: { presentation.folds.hiddenBy[$0] != nil }) {
            clickCommit(commit.hash)
        }
    }

    public func mergedCommits(of commit: Commit) -> [Commit] {
        guard commit.isMerge else { return [] }
        return MergeCollapse.mergedCommits(of: commit, in: presentation.snapshot.history.map(\.commit))
    }

    public func waitForMergeReveal() async {
        await mergeRevealTask?.value
    }

    func expandMerges(hiding hash: String) async {
        while let owner = presentation.folds.hiddenBy[hash], collapsedMerges.remove(owner) != nil {
            await present(presentation.snapshot)
        }
    }
}
