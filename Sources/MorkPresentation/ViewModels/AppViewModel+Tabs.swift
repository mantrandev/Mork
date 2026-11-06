import MorkDomain
import Foundation

extension AppViewModel {
    public static let closedTabLimit = 10
    public static let liveTabLimit = 8

    public var showsTabBar: Bool { tabs.count + (hasManagerTab ? 1 : 0) > 1 }

    public var isManagerActive: Bool { repository == nil }

    public func openManagerTab() {
        guard !tabs.isEmpty else { return }
        hasManagerTab = true
        guard let repository else { return }
        deactivate(repository)
        self.repository = nil
        saveTabs()
    }

    public func closeManagerTab() {
        guard hasManagerTab else { return }
        hasManagerTab = false
        if repository == nil { activateTab(near: tabs.count - 1) }
        saveTabs()
    }

    public var liveTabs: [RepositoryViewModel] {
        tabs.filter { tab in recentTabs.contains { $0 === tab } }
    }

    public func restoreTabs() async {
        guard !hasRestoredTabs else { return }
        hasRestoredTabs = true
        await open(session: dependencies.tabs.loadTabs.execute())
    }

    func open(session: RepositoryTabSession) async {
        let restored = session.tabs.filter { tab(for: $0) == nil }.map(makeTab)
        guard !restored.isEmpty else { return }
        tabs.append(contentsOf: restored)
        if repository == nil, let selected = session.selected.flatMap(tab(for:)) ?? tabs.first {
            activate(selected)
            await waitForTabActivation()
        }
        saveTabs()
        schedulePrefetch()
        for tab in restored {
            await resolveMainRepository(of: tab)
        }
    }

    public func mainRepository(of tab: RepositoryViewModel) -> URL? {
        worktreeMains[tab.url.standardizedFileURL.path]
    }

    public func openWorktree(_ worktree: Worktree) async {
        guard !worktree.isPrunable else {
            errorMessage = "The worktree folder \(worktree.path) is missing. Prune it from the Worktrees section."
            return
        }
        let root = URL(fileURLWithPath: worktree.path)
        if let existing = tab(for: root) {
            focus(existing)
            return
        }
        await openLocated(root, main: knownMainWorktree(of: worktree))
    }

    public func openManaged(_ repository: DiscoveredRepository) async {
        guard !repository.isBare else {
            errorMessage = "“\(repository.name)” is a bare repository. It has no working copy to open."
            return
        }
        await open(repository.url)
    }

    public func openManaged(at url: URL) async {
        if let repository = repositoryManager.groups.lazy.flatMap(\.repositories).first(where: { Self.isSamePath($0.url, url) }) {
            await openManaged(repository)
        } else {
            await open(url)
        }
    }

    public func setAppActive(_ active: Bool) {
        guard isAppActive != active else { return }
        isAppActive = active
        for tab in tabs { tab.setAppActive(active) }
        if active {
            schedulePrefetch()
        } else {
            prefetchTask?.cancel()
            prefetchTask = nil
        }
    }

    public func waitForPrefetch() async {
        await prefetchTask?.value
    }

    func schedulePrefetch() {
        guard isAppActive else { return }
        prefetchTask?.cancel()
        prefetchTask = Task(priority: .utility) { [weak self] in
            await self?.activationTask?.value
            while !Task.isCancelled, let self, self.isAppActive, let next = self.nextPrefetchTab {
                await next.refresh(reportingErrors: false)
            }
        }
    }

    private var nextPrefetchTab: RepositoryViewModel? {
        tabs.first { $0 !== repository && !$0.hasLoaded && !$0.isLoading && !$0.isLocating }
    }

    func resolveMainRepository(of tab: RepositoryViewModel) async {
        let main = await dependencies.repositoryManager.locateMainRepository.execute(repository: tab.url)
        worktreeMains[tab.url.standardizedFileURL.path] = main
    }

    public func selectTab(_ tab: RepositoryViewModel) {
        guard tab !== repository, let index = index(of: tab) else { return }
        guard dependencies.tabs.checkRepositoryExists.execute(url: tab.url) else {
            removeMissingTab(at: index)
            if repository == nil { activateTab(near: index) }
            saveTabs()
            return
        }
        activate(tab)
        saveTabs()
    }

    public func selectTab(number: Int) {
        guard (1...9).contains(number), !tabs.isEmpty else { return }
        let index = number == 9 ? tabs.count - 1 : number - 1
        guard tabs.indices.contains(index) else { return }
        selectTab(tabs[index])
    }

    public func selectNextTab() {
        selectTab(offsetBy: 1)
    }

    public func selectPreviousTab() {
        selectTab(offsetBy: -1)
    }

    public func closeTab(_ tab: RepositoryViewModel) {
        removeTab(tab, remembering: true)
    }

    func removeTab(_ tab: RepositoryViewModel, remembering: Bool) {
        guard let index = index(of: tab) else { return }
        deactivate(tab)
        tabs.remove(at: index)
        if remembering { rememberClosed(tab.url) }
        if tab === repository {
            repository = nil
            activateTab(near: index)
        }
        saveTabs()
    }

    public func closeOtherTabs(_ tab: RepositoryViewModel) {
        guard index(of: tab) != nil else { return }
        for other in tabs where other !== tab {
            deactivate(other)
            rememberClosed(other.url)
        }
        tabs = [tab]
        if tab !== repository {
            repository = nil
            activateTab(near: 0)
        }
        saveTabs()
    }

    public func closeAllTabs() {
        guard !tabs.isEmpty else { return }
        for tab in tabs {
            deactivate(tab)
            rememberClosed(tab.url)
        }
        tabs = []
        repository = nil
        recentRepositories = dependencies.loadRecentRepositories.execute()
        saveTabs()
    }

    public func restoreClosedTab() async {
        guard let url = closedTabs.popLast() else { return }
        await open(url)
    }

    public func moveTab(from source: Int, to destination: Int) {
        guard source != destination, tabs.indices.contains(source), tabs.indices.contains(destination) else { return }
        var reordered = tabs
        reordered.insert(reordered.remove(at: source), at: destination)
        tabs = reordered
        saveTabs()
    }

    public func waitForTabActivation() async {
        await activationTask?.value
    }

    func tab(for url: URL) -> RepositoryViewModel? {
        let path = Self.path(of: url)
        return tabs.first { Self.path(of: $0.url) == path }
    }

    func openTab(containing url: URL) -> RepositoryViewModel? {
        if let exact = tab(for: url) { return exact }
        let path = Self.path(of: url)
        let candidates = tabs.filter { !$0.isLocating }.map { (tab: $0, root: Self.path(of: $0.url)) }
        let nestedRoots = tabs.flatMap { tab in
            tab.worktrees.map { URL(fileURLWithPath: $0.path) } + tab.submodules.map { tab.url(of: $0) }
        }
        let deepest = (candidates.map(\.root) + nestedRoots.map(Self.path(of:)))
            .filter { $0 == path || path.hasPrefix($0 == "/" ? $0 : $0 + "/") }
            .max { $0.count < $1.count }
        return deepest.flatMap { root in candidates.first { $0.root == root }?.tab }
    }

    func knownWorktree(at url: URL) -> Worktree? {
        let path = Self.path(of: url)
        return tabs.lazy.flatMap(\.worktrees).first { !$0.isBare && !$0.isPrunable && Self.path(of: URL(fileURLWithPath: $0.path)) == path }
    }

    func knownMainWorktree(of worktree: Worktree) -> URL? {
        guard !worktree.isMain else { return nil }
        let main = tabs.lazy.map(\.worktrees).first { $0.contains(worktree) }?.first(where: \.isMain)
        return main.map { URL(fileURLWithPath: $0.path) }
    }

    func focus(_ tab: RepositoryViewModel) {
        if repository == nil { hasManagerTab = false }
        if !tab.isLocating { recentRepositories = dependencies.rememberRecentRepository.execute(url: tab.url) }
        selectTab(tab)
    }

    func openLocated(_ root: URL, main: URL? = nil) async {
        if let existing = tab(for: root) {
            focus(existing)
            return
        }
        let tab = makeTab(root)
        if let main { worktreeMains[Self.path(of: root)] = main }
        tabs.append(tab)
        present(tab)
        await load(tab)
    }

    func presentPendingTab(_ url: URL) -> RepositoryViewModel {
        let tab = makeTab(url)
        tab.isLocating = true
        tabs.append(tab)
        present(tab)
        return tab
    }

    func finishLocating(_ pending: RepositoryViewModel, at root: URL) async {
        pending.isLocating = false
        guard let index = index(of: pending) else { return }
        if Self.isSamePath(root, pending.url) {
            await load(pending)
            return
        }
        let wasActive = pending === repository
        if let existing = tab(for: root) {
            tabs.remove(at: index)
            if wasActive { focus(existing) } else { saveTabs() }
            return
        }
        let tab = makeTab(root)
        tabs[index] = tab
        if wasActive { repository = tab }
        await load(tab)
    }

    func discardPendingTab(_ pending: RepositoryViewModel, restoring previous: RepositoryViewModel?) {
        guard let index = index(of: pending) else { return }
        tabs.remove(at: index)
        if pending === repository {
            repository = nil
            if let previous, self.index(of: previous) != nil {
                activate(previous)
            } else {
                activateTab(near: index)
            }
        }
        saveTabs()
    }

    func verifyLocation(of url: URL, focused tab: RepositoryViewModel) async {
        guard let root = try? await dependencies.locateRepository.execute(url: url),
              !Self.isSamePath(root, tab.url), repository === tab else { return }
        await openLocated(root)
    }

    func markLive(_ tab: RepositoryViewModel) {
        guard recentTabs.first !== tab else { return }
        var recent = recentTabs.filter { $0 !== tab }
        recent.insert(tab, at: 0)
        recentTabs = Array(recent.prefix(Self.liveTabLimit))
    }

    func dropClosedLiveTabs() {
        let open = recentTabs.filter { tab in tabs.contains { $0 === tab } }
        if open.count != recentTabs.count { recentTabs = open }
    }

    static func path(of url: URL) -> String {
        let path = url.standardizedFileURL.path
        return path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    static func isSamePath(_ lhs: URL, _ rhs: URL) -> Bool {
        path(of: lhs) == path(of: rhs)
    }

    private func present(_ tab: RepositoryViewModel) {
        if repository == nil { hasManagerTab = false }
        repository.map(deactivate)
        repository = tab
    }

    private func load(_ tab: RepositoryViewModel) async {
        recentRepositories = dependencies.rememberRecentRepository.execute(url: tab.url)
        if tab === repository {
            tab.apply(appliedSettings)
            tab.startWatching()
        }
        saveTabs()
        await tab.refresh()
        await resolveMainRepository(of: tab)
        schedulePrefetch()
    }

    func makeTab(_ root: URL) -> RepositoryViewModel {
        let tab = RepositoryViewModel(url: root, dependencies: dependencies.makeRepositoryDependencies(root))
        tab.setCustomCommands(settings.customCommands.commands)
        tab.commitDetailsTab = commitDetailsTab
        tab.onCommitDetailsTabChange = { [weak self] in self?.commitDetailsTab = $0 }
        tab.onDiffSettingsChange = { [weak self] in self?.settings.set(\.diff, to: $0) }
        tab.onOpenWorktree = { [weak self] in await self?.openWorktree($0) }
        if !isAppActive { tab.setAppActive(false) }
        return tab
    }

    func saveTabs() {
        guard isPrimaryWindow else { return }
        let located = tabs.filter { !$0.isLocating }
        let selected = repository.flatMap { $0.isLocating ? nil : $0.url }
        dependencies.tabs.saveTabs.execute(session: RepositoryTabSession(tabs: located.map(\.url), selected: selected))
    }

    func index(of tab: RepositoryViewModel) -> Int? {
        tabs.firstIndex { $0 === tab }
    }

    private func selectTab(offsetBy offset: Int) {
        let count = tabs.count + (hasManagerTab ? 1 : 0)
        guard count > 1 else { return }
        let current = repository.flatMap(index(of:)) ?? tabs.count
        let next = (current + offset + count) % count
        if next == tabs.count { openManagerTab() } else { selectTab(tabs[next]) }
    }

    func activate(_ tab: RepositoryViewModel) {
        repository.map(deactivate)
        repository = tab
        tab.apply(appliedSettings)
        tab.startWatching()
        activationTask = Task { await tab.refresh() }
    }

    func activateTab(near index: Int) {
        while !tabs.isEmpty {
            let candidateIndex = min(index, tabs.count - 1)
            let candidate = tabs[candidateIndex]
            if dependencies.tabs.checkRepositoryExists.execute(url: candidate.url) {
                activate(candidate)
                return
            }
            removeMissingTab(at: candidateIndex)
        }
        recentRepositories = dependencies.loadRecentRepositories.execute()
    }

    private func removeMissingTab(at index: Int) {
        let tab = tabs.remove(at: index)
        deactivate(tab)
        errorMessage = "“\(tab.name)” is no longer on disk (\(tab.url.path)), so its tab was closed."
    }

    func deactivate(_ tab: RepositoryViewModel) {
        tab.stopWatching()
        tab.stopAutoFetch()
    }

    private func rememberClosed(_ url: URL) {
        closedTabs.append(url)
        if closedTabs.count > Self.closedTabLimit { closedTabs.removeFirst(closedTabs.count - Self.closedTabLimit) }
    }
}
