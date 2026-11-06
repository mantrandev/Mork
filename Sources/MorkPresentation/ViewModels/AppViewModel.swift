import AppKit
import MorkDomain
import Foundation
import Observation

@MainActor
@Observable
public final class AppViewModel {
    public enum BottomPanelTab: String, CaseIterable, Identifiable, Sendable {
        case console = "Git Console"
        case terminal = "Terminal"

        public var id: String { rawValue }
    }

    static let showsBottomPanelKey = "showsBottomPanel"
    static let bottomPanelHeightKey = "bottomPanelHeight.v2"
    static let commitHeaderKey = "commitDetails.showsHeader"
    static let commitFilesPlacementKey = "commitDetails.filesPlacement"
    static let commitTabKey = "commitDetails.tab"
    public static let defaultBottomPanelHeight: Double = 300
    public static let minimumBottomPanelHeight: Double = 160

    public internal(set) var repository: RepositoryViewModel? {
        didSet {
            updateExpandedRepositoryTabWidth()
            if let repository {
                markLive(repository)
                lastRepository = repository
            }
        }
    }
    public internal(set) var expandedRepositoryTabWidth = Metrics.RepositoryTab.expandedMinimumWidth
    @ObservationIgnored private var measuredRepositoryTabTitle: String?
    private var lastRepository: RepositoryViewModel?
    public var retainedRepository: RepositoryViewModel? {
        repository ?? lastRepository.flatMap { last in tabs.contains { $0 === last } ? last : nil }
    }
    public internal(set) var tabs: [RepositoryViewModel] = [] {
        didSet {
            dropClosedLiveTabs()
            if tabs.isEmpty { hasManagerTab = false }
        }
    }
    public internal(set) var hasManagerTab = false
    var recentTabs: [RepositoryViewModel] = []
    public internal(set) var closedTabs: [URL] = []
    public internal(set) var quickLaunch: QuickLaunchViewModel?
    public var rebaseSession: InteractiveRebaseViewModel?
    public var errorMessage: String?
    public let console: ConsoleViewModel
    public let settings: SettingsViewModel
    public let accounts: AccountsViewModel
    public let sshKeys: SSHKeysViewModel
    public let cloneAccounts: CloneAccountsViewModel
    public let authorAvatars: AuthorAvatarImageCache
    public internal(set) var recentRepositories: [URL] = [] {
        didSet {
            repositoryManager.recents = recentRepositories
            if let primaryWindow, primaryWindow.recentRepositories != recentRepositories {
                primaryWindow.recentRepositories = recentRepositories
            }
        }
    }
    public let repositoryManager: RepositoryManagerViewModel
    public internal(set) var workspaceCatalog: WorkspaceCatalog
    public internal(set) var tabAppearances: TabAppearances
    public internal(set) var worktreeMains: [String: URL] = [:]
    public var isCloneSheetPresented = false
    public var isWorkspaceSheetPresented = false
    public var renamingTab: RepositoryViewModel?
    public private(set) var isCloning = false
    public private(set) var cloneProgress = GitProgressLog()
    public var cloneErrorMessage: String?
    public private(set) var bottomPanelTab: BottomPanelTab = .console
    public private(set) var terminalFocusRequest = 0
    private var terminalFocusRequests: [URL: Int] = [:]
    public var bottomPanelHeight: Double = AppViewModel.defaultBottomPanelHeight {
        didSet {
            guard bottomPanelHeight != oldValue else { return }
            preferences.set(bottomPanelHeight, forKey: Self.bottomPanelHeightKey)
            hasSavedBottomPanelHeight = true
        }
    }
    private var hasSavedBottomPanelHeight = false
    public var savedBottomPanelHeight: Double? {
        hasSavedBottomPanelHeight ? bottomPanelHeight : nil
    }
    public var showsBottomPanel: Bool {
        didSet { preferences.set(showsBottomPanel, forKey: Self.showsBottomPanelKey) }
    }
    public var commitDetailsLayout: CommitDetailsLayout {
        didSet {
            guard commitDetailsLayout != oldValue else { return }
            preferences.set(commitDetailsLayout.showsHeader, forKey: Self.commitHeaderKey)
            preferences.set(commitDetailsLayout.filesPlacement.rawValue, forKey: Self.commitFilesPlacementKey)
        }
    }
    public var commitDetailsTab: CommitDetailsTab {
        didSet {
            guard commitDetailsTab != oldValue else { return }
            preferences.set(commitDetailsTab.rawValue, forKey: Self.commitTabKey)
            tabs.forEach { $0.commitDetailsTab = commitDetailsTab }
        }
    }

    let dependencies: AppDependencies
    @ObservationIgnored private let preferences: UserDefaults
    @ObservationIgnored private var cloneTask: Task<URL, any Error>?
    @ObservationIgnored var activationTask: Task<Void, Never>?
    @ObservationIgnored var hasRestoredTabs = false
    @ObservationIgnored var appliedSettings: AppSettings
    @ObservationIgnored var prefetchTask: Task<Void, Never>?
    @ObservationIgnored var isAppActive = true
    public let isPrimaryWindow: Bool
    @ObservationIgnored private weak var primaryWindow: AppViewModel?
    @ObservationIgnored private var otherWindows: [WeakWindow] = []
    @ObservationIgnored private var pendingWindowTabs: [URL] = []

    public init(dependencies: AppDependencies, console: ConsoleViewModel, preferences: UserDefaults = .standard) {
        isPrimaryWindow = true
        self.dependencies = dependencies
        self.console = console
        self.preferences = preferences
        let settings = SettingsViewModel(dependencies: dependencies.settings)
        let current = settings.settings
        self.settings = settings
        let accounts = AccountsViewModel(dependencies: dependencies.accounts)
        self.accounts = accounts
        sshKeys = SSHKeysViewModel(dependencies: dependencies.ssh, accounts: accounts)
        cloneAccounts = CloneAccountsViewModel(dependencies: dependencies.accounts)
        appliedSettings = current
        let loadAuthorAvatar = dependencies.loadAuthorAvatar
        authorAvatars = AuthorAvatarImageCache(isEnabled: current.showsAuthorAvatars) { await loadAuthorAvatar?.execute(email: $0) }
        showsBottomPanel = current.showsConsoleOnLaunch ? preferences.object(forKey: Self.showsBottomPanelKey) as? Bool ?? true : false
        let storedHeight = preferences.double(forKey: Self.bottomPanelHeightKey)
        bottomPanelHeight = storedHeight >= Self.minimumBottomPanelHeight ? storedHeight : Self.defaultBottomPanelHeight
        hasSavedBottomPanelHeight = storedHeight >= Self.minimumBottomPanelHeight
        commitDetailsLayout = CommitDetailsLayout(
            showsHeader: preferences.object(forKey: Self.commitHeaderKey) as? Bool ?? true,
            filesPlacement: preferences.string(forKey: Self.commitFilesPlacementKey).flatMap(CommitDetailsLayout.FilesPlacement.init(rawValue:)) ?? .beside
        )
        commitDetailsTab = preferences.string(forKey: Self.commitTabKey).flatMap(CommitDetailsTab.init(rawValue:)) ?? .commit
        console.showsLessons = current.showsLessons
        console.showsReadCommands = current.showsReadCommands
        repositoryManager = RepositoryManagerViewModel(dependencies: dependencies.repositoryManager)
        workspaceCatalog = dependencies.tabs.loadWorkspaces.execute()
        tabAppearances = dependencies.tabs.loadTabAppearances.execute()
        recentRepositories = dependencies.loadRecentRepositories.execute()
        repositoryManager.recents = recentRepositories
        settings.onChange = { [weak self] settings in
            guard let self else { return }
            apply(settings)
            liveWindows.forEach { $0.applyToWindow(settings) }
        }
        settings.customCommands.onChange = { [weak self] commands in
            guard let self else { return }
            ([self] + liveWindows).forEach { window in window.tabs.forEach { $0.setCustomCommands(commands) } }
        }
    }

    private init(sharing primary: AppViewModel) {
        isPrimaryWindow = false
        primaryWindow = primary
        dependencies = primary.dependencies
        console = primary.console
        preferences = primary.preferences
        settings = primary.settings
        accounts = primary.accounts
        sshKeys = primary.sshKeys
        cloneAccounts = primary.cloneAccounts
        authorAvatars = primary.authorAvatars
        appliedSettings = primary.appliedSettings
        showsBottomPanel = primary.showsBottomPanel
        bottomPanelHeight = primary.bottomPanelHeight
        hasSavedBottomPanelHeight = primary.hasSavedBottomPanelHeight
        commitDetailsLayout = primary.commitDetailsLayout
        commitDetailsTab = primary.commitDetailsTab
        repositoryManager = primary.repositoryManager
        workspaceCatalog = primary.workspaceCatalog
        tabAppearances = primary.tabAppearances
        recentRepositories = primary.recentRepositories
        hasRestoredTabs = true
    }

    public func makeWindow() -> AppViewModel {
        let primary = primaryWindow ?? self
        let window = AppViewModel(sharing: primary)
        primary.otherWindows = primary.otherWindows.filter { $0.window != nil } + [WeakWindow(window: window)]
        return window
    }

    public func appearance(of tab: RepositoryViewModel) -> TabAppearance {
        (primaryWindow ?? self).tabAppearances.appearance(for: tab.url)
    }

    public func title(of tab: RepositoryViewModel) -> String {
        appearance(of: tab).title ?? tab.name
    }

    func updateExpandedRepositoryTabWidth() {
        let title = repository.map { self.title(of: $0) } ?? "Repository Manager"
        guard title != measuredRepositoryTabTitle else { return }
        measuredRepositoryTabTitle = title
        let titleWidth = (title as NSString).size(withAttributes: [
            .font: NSFont.systemFont(ofSize: Metrics.FontSize.body, weight: .medium)
        ]).width
        expandedRepositoryTabWidth = min(
            Metrics.RepositoryTab.expandedMaximumWidth,
            max(Metrics.RepositoryTab.expandedMinimumWidth, titleWidth + Metrics.RepositoryTab.titleAccessoryWidth)
        )
    }

    public func renameTab(_ tab: RepositoryViewModel, to title: String?) {
        updateAppearances { $0.rename(tab.url, to: title) }
    }

    public func setColor(_ color: TabColor?, for tab: RepositoryViewModel) {
        updateAppearances { $0.setColor(color, for: tab.url) }
    }

    private func updateAppearances(_ change: (inout TabAppearances) -> Void) {
        let owner = primaryWindow ?? self
        var appearances = owner.tabAppearances
        change(&appearances)
        guard appearances != owner.tabAppearances else { return }
        owner.tabAppearances = appearances
        owner.updateExpandedRepositoryTabWidth()
        owner.liveWindows.forEach { $0.updateExpandedRepositoryTabWidth() }
        dependencies.tabs.saveTabAppearances.execute(appearances: appearances)
    }

    public func moveTabToNewWindow(_ tab: RepositoryViewModel) {
        guard index(of: tab) != nil else { return }
        (primaryWindow ?? self).pendingWindowTabs.append(tab.url)
        removeTab(tab, remembering: false)
    }

    public func openPendingWindowTabs() async {
        let primary = primaryWindow ?? self
        let urls = primary.pendingWindowTabs
        primary.pendingWindowTabs = []
        for url in urls { await open(url) }
    }

    private var liveWindows: [AppViewModel] {
        otherWindows.compactMap(\.window)
    }

    private func applyToWindow(_ settings: AppSettings) {
        appliedSettings = settings
        repository?.apply(settings)
    }

    public func open(_ url: URL) async {
        if let match = openTab(containing: url) {
            focus(match)
            if !Self.isSamePath(match.url, url) { await verifyLocation(of: url, focused: match) }
            return
        }
        if let worktree = knownWorktree(at: url) {
            await openLocated(URL(fileURLWithPath: worktree.path), main: knownMainWorktree(of: worktree))
            return
        }
        let previous = repository
        let pending = presentPendingTab(url)
        do {
            let root = try await dependencies.locateRepository.execute(url: url)
            await finishLocating(pending, at: root)
        } catch {
            discardPendingTab(pending, restoring: previous)
            errorMessage = error.localizedDescription
            recentRepositories = dependencies.loadRecentRepositories.execute()
        }
    }

    public func openChosenFolder() async {
        guard let url = await repositoryManager.chooseFolder(prompt: "Open") else { return }
        await open(url)
    }

    public func initializeChosenFolder() async {
        guard let url = await repositoryManager.chooseFolder(prompt: "git init") else { return }
        await initialize(url)
    }

    public func initialize(_ url: URL) async {
        do {
            let root = try await dependencies.initializeRepository.execute(url: url)
            await openLocated(root)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func close() {
        if let repository { closeTab(repository) }
    }

    public func showSettings(_ tab: SettingsViewModel.Tab) {
        settings.selectedTab = tab
    }

    public func makeStatistics(for repository: URL) -> StatisticsViewModel {
        StatisticsViewModel(repositoryName: repository.lastPathComponent, loadStatistics: dependencies.makeRepositoryDependencies(repository).statistics.loadStatistics)
    }

    public func showCloneSheet() {
        cloneErrorMessage = nil
        cloneProgress = GitProgressLog()
        isCloneSheetPresented = true
    }

    public func clone(source: String, destination: URL) async {
        guard !isCloning else { return }
        isCloning = true
        cloneErrorMessage = nil
        cloneProgress = GitProgressLog()
        let (lines, continuation) = AsyncStream<String>.makeStream()
        let cloneRepository = dependencies.cloneRepository
        let task = Task {
            defer { continuation.finish() }
            return try await cloneRepository.execute(source: source, destination: destination) { continuation.yield($0) }
        }
        cloneTask = task
        for await line in lines {
            cloneProgress.append(line)
        }
        let result = await task.result
        cloneTask = nil
        isCloning = false
        switch result {
        case let .success(root):
            isCloneSheetPresented = false
            await open(root)
        case .failure(is CancellationError):
            cloneProgress.append("Clone cancelled.")
        case let .failure(error):
            cloneErrorMessage = error.localizedDescription
        }
    }

    public func cancelClone() {
        cloneTask?.cancel()
    }

    public func clearRecentRepositories() {
        dependencies.clearRecentRepositories.execute()
        recentRepositories = []
    }

    public func toggleBottomPanel() {
        showsBottomPanel.toggle()
    }

    public func selectBottomPanelTab(_ tab: BottomPanelTab) {
        bottomPanelTab = tab
        guard tab == .terminal else { return }
        terminalFocusRequest += 1
        if let url = repository?.url { terminalFocusRequests[url] = terminalFocusRequest }
    }

    public func terminalFocusRequest(for url: URL) -> Int {
        terminalFocusRequests[url] ?? 0
    }

    public func showTerminal() {
        showsBottomPanel = true
        selectBottomPanelTab(.terminal)
    }

    private func apply(_ settings: AppSettings) {
        console.showsLessons = settings.showsLessons
        if settings.showsReadCommands != appliedSettings.showsReadCommands {
            console.showsReadCommands = settings.showsReadCommands
        }
        if authorAvatars.isEnabled != settings.showsAuthorAvatars {
            authorAvatars.isEnabled = settings.showsAuthorAvatars
        }
        appliedSettings = settings
        repository?.apply(settings)
    }
}

private struct WeakWindow {
    weak var window: AppViewModel?
}
