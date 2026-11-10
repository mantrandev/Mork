import MorkDomain
import Foundation

extension RepositoryViewModel {
    public var isRebasing: Bool { repositoryState == .rebasing }
    public var hasUncommittedChanges: Bool { changes.contains(where: \.isUncommitted) }

    public func makeInteractiveRebase(onto commit: Commit) async -> InteractiveRebaseViewModel? {
        await makeInteractiveRebase(base: .commit(commit))
    }

    public func makeInteractiveRebase(onto branch: Branch) async -> InteractiveRebaseViewModel? {
        await makeInteractiveRebase(base: .branch(branch))
    }

    private func makeInteractiveRebase(base: RebaseBase) async -> InteractiveRebaseViewModel? {
        let branch = currentBranch
        do {
            let loadRebaseSteps = dependencies.rebase.loadRebaseSteps
            let range = try await reading { try await loadRebaseSteps.execute(base: base, branch: branch) }
            return InteractiveRebaseViewModel(
                base: base,
                branchName: branch?.name ?? "HEAD",
                steps: range.steps,
                skippedMerges: range.skippedMerges,
                hasUncommittedChanges: hasUncommittedChanges,
                changes: RebaseCommitChanges(
                    summary: { [weak self] commit in
                        await self?.summaryTask(for: commit).value ?? .failure(CancellationError())
                    },
                    diffs: { [weak self] files, commit in
                        await self?.inlineDiffStates(of: files, in: commit) ?? [:]
                    },
                    fullDiff: { [weak self] file, commit in
                        await self?.fullDiffState(of: file, in: commit) ?? .failed(CancellationError().localizedDescription)
                    },
                    settings: { [weak self] in self?.settings.diff ?? DiffSettings() },
                    changeSettings: { [weak self] change in self?.changeDiffSettings(change) }
                )
            ) { [weak self] steps, options in
                await self?.runInteractiveRebase(onto: base, steps: steps, options: options)
            }
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    public func rebaseMenuTitle(onto branch: Branch) -> String {
        let action = hasUncommittedChanges ? "Stash and Rebase" : "Rebase"
        return "\(action) on '\(branch.name)'"
    }

    public func rebase(onto branch: Branch, autostash: Bool) async {
        let current = currentBranch
        await perform { try await $0.rebase.rebaseBranch.execute(onto: branch, current: current, autostash: autostash) }
    }

    public func continueRebase() async {
        await perform { try await $0.rebase.continueRebase.execute() }
    }

    public func skipRebase() async {
        await perform { try await $0.rebase.skipRebase.execute() }
    }

    public func abortRebase() async {
        await perform { try await $0.rebase.abortRebase.execute() }
    }

    private func runInteractiveRebase(onto base: RebaseBase, steps: [RebaseStep], options: InteractiveRebaseOptions) async {
        await perform { try await $0.rebase.runInteractiveRebase.execute(base: base, steps: steps, options: options) }
    }
}

extension RepositoryViewModel {
    public var lastPullMode: PullMode { dependencies.remoteOptions.loadPullMode.execute() }
    public var lastPullAutostash: Bool { dependencies.remoteOptions.loadPullAutostash.execute() }

    @discardableResult
    public func pull(options: PullOptions) async -> Bool {
        let branch = currentBranch
        let pulled = await perform { try await $0.remoteOptions.pullWithOptions.execute(branch: branch, options: options) }
        if pulled { fetchAllInBackground() }
        return pulled
    }

    @discardableResult
    public func pull(mode: PullMode) async -> Bool {
        let branch = currentBranch
        let pulled = await perform { try await $0.remoteOptions.pullWithMode.execute(branch: branch, mode: mode) }
        if pulled { fetchAllInBackground() }
        return pulled
    }

    func fetchAllInBackground() {
        backgroundFetch = Task { [weak self] in
            guard let self else { return }
            await tracking(.fetch) {
                await perform { dependencies in
                    try? await dependencies.remoteOptions.fetchWithOptions.execute(options: FetchOptions(remote: nil, prune: false, tags: false))
                }
            }
        }
    }

    public func waitForBackgroundFetch() async {
        await backgroundFetch?.value
    }

    public func loadRemotes() async -> [String] {
        do {
            return try await dependencies.remoteOptions.loadRemotes.execute()
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    @discardableResult
    public func push(_ branch: Branch, to remote: String, includeTags: Bool, forceWithLease: Bool) async -> Bool {
        await perform { try await $0.remoteOptions.pushWithOptions.execute(branch: branch, remote: remote, includeTags: includeTags, forceWithLease: forceWithLease) }
    }

    @discardableResult
    public func fetch(options: FetchOptions) async -> Bool {
        var succeeded = false
        await tracking(.fetch) { succeeded = await perform { try await $0.remoteOptions.fetchWithOptions.execute(options: options) } }
        return succeeded
    }
}
