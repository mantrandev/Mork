import MorkDomain
import Foundation

extension RepositoryViewModel {
    public enum SidebarSelection: Hashable, Sendable {
        case pane(Pane)
        case branch(String)
        case remoteBranch(String)
        case tag(String)
        case stash(String)
        case worktree(String)
        case submodule(String)
    }

    public var sidebarSelection: SidebarSelection { sidebarItem ?? .pane(pane) }

    public func selectSidebar(_ selection: SidebarSelection) {
        sidebarTask?.cancel()
        sidebarTask = nil
        if case let .pane(pane) = selection {
            sidebarItem = nil
            self.pane = pane
            return
        }
        if case let .worktree(path) = selection, let worktree = worktrees.first(where: { $0.path == path }), worktree.isPrunable {
            notice = Notice(
                title: "Worktree folder is missing",
                message: "\(worktree.path) no longer exists, so its commits cannot be shown. Prune Missing Worktrees (git worktree prune) cleans it up."
            )
            return
        }
        sidebarItem = selection
        if case let .branch(name) = selection, let branch = localBranches.first(where: { $0.name == name }) {
            rememberBranch(branch, among: localBranches)
        }
        if case let .remoteBranch(name) = selection, let branch = remoteBranches.first(where: { $0.name == name }) {
            rememberBranch(branch, among: remoteBranches)
        }
        guard let revision = revision(of: selection) else { return }
        pane = .history
        if let loaded = loadedTip(of: selection) {
            revealLoaded(loaded)
            return
        }
        sidebarTask = Task { [weak self] in
            guard let self else { return }
            guard !Task.isCancelled, sidebarItem == selection else { return }
            await reveal(selection, at: revision)
        }
    }

    public func activateSidebar(_ selection: SidebarSelection, openRepository: (URL) -> Void) async {
        switch selection {
        case .pane, .tag, .stash:
            return
        case let .branch(name):
            guard let branch = localBranches.first(where: { $0.name == name }), !branch.isCurrent else { return }
            await checkout(branch)
        case let .remoteBranch(name):
            guard let branch = remoteBranches.first(where: { $0.name == name }) else { return }
            await checkout(branch)
        case let .worktree(path):
            guard let row = worktreeRows.first(where: { $0.worktree.path == path }), !row.isCurrent, !row.worktree.isPrunable else { return }
            openRepository(url(of: row.worktree))
        case let .submodule(path):
            guard let submodule = submodules.first(where: { $0.path == path }) else { return }
            guard submodule.isInitialized else {
                errorMessage = SubmoduleError.notInitialized(submodule.path).errorDescription
                return
            }
            openRepository(url(of: submodule))
        }
    }

    public func waitForSidebarReveal() async {
        await sidebarTask?.value
    }

    public func isPinned(_ branch: Branch) -> Bool { historyOptions.isPinned(branch) }
    public func isHidden(_ branch: Branch) -> Bool { historyOptions.isHidden(branch) }
    public func isFiltered(to branch: Branch) -> Bool { historyOptions.isFiltered(to: branch) }

    public var tagSortOrder: TagSortOrder { sidebarOptions.tagSortOrder }

    public var branchSortOrder: BranchSortOrder { sidebarOptions.branchSortOrder }

    public var remoteBranchSortOrder: BranchSortOrder { sidebarOptions.remoteBranchSortOrder }

    public func setRemoteBranchSortOrder(_ order: BranchSortOrder) async {
        guard order != remoteBranchSortOrder else { return }
        var options = sidebarOptions
        options.remoteBranchSortOrder = order
        saveSidebarOptions(options)
        await present(snapshot)
    }

    public var staleLocalBranches: [Branch] {
        localBranches.filter { !$0.isCurrent && $0.isUpstreamGone }
    }

    public func setBranchSortOrder(_ order: BranchSortOrder) async {
        guard order != branchSortOrder else { return }
        var options = sidebarOptions
        options.branchSortOrder = order
        saveSidebarOptions(options)
        await present(snapshot)
    }

    func rememberBranch(_ branch: Branch, among branches: [Branch]) {
        var options = sidebarOptions
        let keyPath: WritableKeyPath<SidebarOptions, [String]> = branch.isRemote ? \.recentlyUsedRemoteBranches : \.recentlyUsedBranches
        let existing = Set(branches.filter { $0.isRemote == branch.isRemote }.map(\.fullName))
        options[keyPath: keyPath] = Array(([branch.fullName] + options[keyPath: keyPath].filter { $0 != branch.fullName && existing.contains($0) }).prefix(100))
        if options[keyPath: keyPath] != sidebarOptions[keyPath: keyPath] { saveSidebarOptions(options) }
    }

    public func setTagSortOrder(_ order: TagSortOrder) {
        guard order != tagSortOrder else { return }
        var options = sidebarOptions
        options.tagSortOrder = order
        saveSidebarOptions(options)
        rebuildTagSidebarRows()
    }

    func toggleTagFolder(_ id: String) {
        let path = String(id.dropFirst("folder:".count))
        collapsedTagFolders.formSymmetricDifference([path])
        rebuildTagSidebarRows()
    }

    func rebuildTagSidebarRows() {
        tagSidebarRows = TagSidebarRows.make(tags: tags, order: tagSortOrder, collapsed: collapsedTagFolders)
    }

    public func togglePin(_ branch: Branch) async {
        var options = historyOptions
        options.pinnedBranches = Self.toggling(branch.fullName, in: options.pinnedBranches)
        saveHistoryOptions(options)
        await present(snapshot)
    }

    public func toggleHistoryFilter(_ branch: Branch) async {
        var options = historyOptions
        let references = historyReferences(for: branch)
        if options.isFiltered(to: branch) {
            options.filteredBranches.removeAll { references.contains($0) }
        } else {
            options.filteredBranches += references.filter { !options.filteredBranches.contains($0) }
        }
        saveHistoryOptions(options)
        if !options.filteredBranches.isEmpty { pane = .history }
        await refresh()
    }

    public func clearHistoryFilter() async {
        guard !historyOptions.filteredBranches.isEmpty else { return }
        var options = historyOptions
        options.filteredBranches = []
        saveHistoryOptions(options)
        await refresh()
    }

    public func toggleHidden(_ branch: Branch) async {
        var options = historyOptions
        let references = historyReferences(for: branch)
        if options.isHidden(branch) {
            options.hiddenBranches.removeAll { references.contains($0) }
        } else {
            options.hiddenBranches += references.filter { !options.hiddenBranches.contains($0) }
            options.filteredBranches.removeAll { references.contains($0) }
        }
        saveHistoryOptions(options)
        await refresh()
    }

    private func historyReferences(for branch: Branch) -> [String] {
        guard !branch.isRemote, !branch.isUpstreamGone, let upstream = branch.upstream,
              let remote = branches.first(where: { $0.isRemote && $0.name == upstream }) else {
            return [branch.fullName]
        }
        return [branch.fullName, remote.fullName]
    }

    func reconcileSidebarItem() {
        guard let item = sidebarItem else { return }
        let exists = switch item {
        case .pane: true
        case let .branch(name): localBranches.contains { $0.name == name }
        case let .remoteBranch(name): remoteBranches.contains { $0.name == name }
        case let .tag(name): tags.contains { $0.name == name }
        case let .stash(reference): stashes.contains { $0.reference == reference }
        case let .worktree(path): worktrees.contains { $0.path == path }
        case let .submodule(path): submodules.contains { $0.path == path }
        }
        if !exists { sidebarItem = nil }
    }

    private func revision(of selection: SidebarSelection) -> String? {
        switch selection {
        case .pane, .submodule: nil
        case let .branch(name): "refs/heads/\(name)"
        case let .remoteBranch(name): "refs/remotes/\(name)"
        case let .tag(name): "refs/tags/\(name)"
        case let .stash(reference): reference
        case let .worktree(path): worktrees.first { $0.path == path }?.head
        }
    }

    private func reveal(_ selection: SidebarSelection, at revision: String) async {
        if case .stash = selection, historyOptions.hidesStashes {
            await setHistoryOption(\.hidesStashes, to: false)
        }
        let target: Commit
        do {
            target = try await dependencies.exploration.loadCommit.execute(revision: revision)
        } catch {
            guard !Task.isCancelled, sidebarItem == selection else { return }
            errorMessage = error.localizedDescription
            return
        }
        guard !Task.isCancelled, sidebarItem == selection else { return }
        await loadHistory(through: target.hash)
        guard !Task.isCancelled, sidebarItem == selection else { return }
        revealLoaded(loadedCommit(hash: target.hash) ?? target)
    }

    private func loadHistory(through hash: String) async {
        while loadedCommit(hash: hash) == nil, hasMoreHistory, !Task.isCancelled {
            let loaded = historyRows.count
            loadMoreHistory()
            await waitForHistoryPage()
            if historyRows.count == loaded { return }
        }
    }

    private func revealLoaded(_ commit: Commit) {
        if isSearchActive && (search.isSearching || search.results?.contains(where: { $0.commit.hash == commit.hash }) != true) { clearSearch() }
        pane = .history
        reveal(commit)
    }

    private func loadedCommit(hash: String) -> Commit? {
        presentation.historyIndex[hash].flatMap { historyRows.indices.contains($0) ? historyRows[$0].commit : nil }
    }

    private func loadedTip(of selection: SidebarSelection) -> Commit? {
        let hash: String? = switch selection {
        case let .branch(name): localBranches.first { $0.name == name }?.hash
        case let .remoteBranch(name): remoteBranches.first { $0.name == name }?.hash
        case let .worktree(path): worktrees.first { $0.path == path }?.head
        case .pane, .tag, .stash, .submodule: nil
        }
        guard let hash, !hash.isEmpty else { return nil }
        return loadedCommit(hash: hash)
    }

    func saveSidebarOptions(_ options: SidebarOptions) {
        sidebarOptions = options
        dependencies.sidebarOptions.save.execute(options: options, repository: url)
    }

    func saveHistoryOptions(_ options: HistoryOptions) {
        historyOptions = options
        dependencies.exploration.saveHistoryOptions.execute(options: options, repository: url)
        if isSearchActive { scheduleSearch() }
    }

    private static func toggling(_ value: String, in list: [String]) -> [String] {
        list.contains(value) ? list.filter { $0 != value } : list + [value]
    }
}
