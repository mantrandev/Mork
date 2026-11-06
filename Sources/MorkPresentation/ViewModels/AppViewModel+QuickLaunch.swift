import MorkDomain
import Foundation

extension AppViewModel {
    public func showQuickLaunch() {
        let tabItems = tabs.map { QuickLaunchItem(tab: $0.url) }
        let recentItems = recentRepositories.filter { tab(for: $0) == nil }.map { QuickLaunchItem(recent: $0) }
        let shownPaths = Set((tabs.map(\.url) + recentRepositories).map(\.standardizedFileURL.path))
        let managedItems = repositoryManager.openableRepositories
            .filter { !shownPaths.contains($0.url.standardizedFileURL.path) }
            .map { QuickLaunchItem(repository: $0.url) }
        let commandItems = availableCommands.map { command in
            QuickLaunchItem(command: command, subtitle: subtitle(for: command))
        }
        let branchItems = (repository?.branches ?? []).filter { !$0.isCurrent }.map { QuickLaunchItem(branch: $0) }
        let tagItems = (repository?.tags ?? []).map { QuickLaunchItem(tag: $0) }
        let customItems = (repository?.customCommands(for: .quickLaunch) ?? []).map { QuickLaunchItem(customCommand: $0) }
        let suggestions = tabItems + recentItems + commandItems + customItems + managedItems
        quickLaunch = QuickLaunchViewModel(candidates: suggestions + branchItems + tagItems, suggestions: suggestions)
    }

    public func dismissQuickLaunch() {
        quickLaunch = nil
    }

    public func toggleQuickLaunch() {
        if quickLaunch == nil { showQuickLaunch() } else { dismissQuickLaunch() }
    }

    public func runQuickLaunchSelection() async {
        guard let item = quickLaunch?.selectedItem else { return }
        await runQuickLaunch(item)
    }

    public func runQuickLaunch(_ item: QuickLaunchItem) async {
        quickLaunch = nil
        switch item.kind {
        case let .tab(url):
            guard let tab = tab(for: url) else { return }
            selectTab(tab)
            await waitForTabActivation()
        case let .recent(url), let .repository(url):
            await open(url)
        case let .branch(branch):
            await repository?.checkout(branch)
        case let .tag(tag):
            repository?.selectSidebar(.tag(tag.name))
        case let .command(command):
            await run(command)
        case let .customCommand(command):
            await repository?.run(command)
        }
    }

    private var availableCommands: [QuickLaunchCommand] {
        var commands: [QuickLaunchCommand] = [.openRepository, .cloneRepository, .initializeRepository, .addRepositoryFolder, .rescanRepositoryFolders]
        if !closedTabs.isEmpty { commands.append(.restoreClosedTab) }
        guard let repository else { return commands }
        commands.append(.closeTab)
        if tabs.count > 1 { commands += [.nextTab, .previousTab] }
        commands.append(.fetch)
        if !repository.isDetachedHead { commands += [.pull, .push, .pullWithOptions, .pushWithOptions] }
        commands += [.newBranch, .newTag, .stash, .showChanges, .showHistory, .showReflog, .refresh, .applyPatch]
        if repository.selectedCommit != nil { commands.append(.interactiveRebase) }
        commands += [.toggleConsole, .openTerminal]
        return commands
    }

    private func subtitle(for command: QuickLaunchCommand) -> String {
        guard command == .interactiveRebase, let commit = repository?.selectedCommit else { return "Command" }
        return "Rebase onto \(commit.shortHash) \(commit.subject)"
    }

    private func run(_ command: QuickLaunchCommand) async {
        switch command {
        case .openRepository, .initializeRepository: return
        case .cloneRepository: showCloneSheet()
        case .addRepositoryFolder: await repositoryManager.addFolder()
        case .rescanRepositoryFolders: await repositoryManager.rescan()
        case .restoreClosedTab: await restoreClosedTab()
        case .closeTab: close()
        case .nextTab:
            selectNextTab()
            await waitForTabActivation()
        case .previousTab:
            selectPreviousTab()
            await waitForTabActivation()
        case .toggleConsole: toggleBottomPanel()
        case .openTerminal: showTerminal()
        default:
            guard let repository else { return }
            await run(command, in: repository)
        }
    }

    private func run(_ command: QuickLaunchCommand, in repository: RepositoryViewModel) async {
        switch command {
        case .fetch: await repository.fetch()
        case .pull: await repository.pull()
        case .push: await repository.push()
        case .pullWithOptions: repository.sheet = .pull
        case .pushWithOptions: repository.sheet = .push
        case .newBranch: repository.sheet = .branch
        case .newTag: repository.sheet = .tag
        case .stash: repository.sheet = .stash
        case .showChanges: repository.pane = .changes
        case .showHistory: repository.pane = .history
        case .showReflog: repository.pane = .reflog
        case .refresh: await repository.refresh()
        case .applyPatch: await repository.beginApplyPatch()
        case .interactiveRebase:
            guard let commit = repository.selectedCommit else { return }
            rebaseSession = await repository.makeInteractiveRebase(onto: commit)
        default: return
        }
    }
}
