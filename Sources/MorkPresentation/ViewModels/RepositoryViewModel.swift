import MorkDomain
import Foundation
import Observation

@MainActor
@Observable
public final class RepositoryViewModel {
    public static let historyLimit = 500
    static let historyPrefetchDistance = 100

    public enum Pane: String, CaseIterable, Identifiable, Sendable {
        case changes = "Changes"
        case history = "History"
        case reflog = "Reflog"

        public var id: String { rawValue }
    }

    public enum Selection: Hashable, Sendable {
        case file(FileChange, staged: Bool)
        case commit(Commit)
        case commitFile(Commit, CommitFileChange)
    }

    public enum Sheet: String, Identifiable, Sendable {
        case branch
        case tag
        case stash
        case pull
        case push
        case fetch
        case worktree
        case startLeanBranch
        case finishLeanBranch

        public var id: String { rawValue }
    }

    public enum Detail: Equatable, Sendable {
        case empty
        case loading
        case loaded(String)
        case failed(String)
    }

    public enum Operation: Hashable, Sendable {
        case fetch
        case pull
        case push
        case refresh
    }

    public enum CommitInfo: Equatable, Sendable {
        case empty
        case loading
        case loaded(CommitSummary)
        case failed(String)
    }

    public let url: URL
    public private(set) var branches: [Branch] = []
    public private(set) var changes: [FileChange] = []
    public private(set) var hasTabChanges = false
    public private(set) var historyRows: [GraphRow] = []
    public private(set) var stashes: [Stash] = []
    public private(set) var tags: [Tag] = []
    var tagSidebarRows: [TagSidebarRow] = []
    @ObservationIgnored var collapsedTagFolders: Set<String> = []
    public private(set) var repositoryState: RepositoryState = .clean
    public private(set) var remotes: [Remote] = []
    public private(set) var worktrees: [Worktree] = []
    public private(set) var submodules: [Submodule] = []
    public private(set) var bisectSession: BisectSession?
    public private(set) var currentBranch: Branch?
    public private(set) var localBranches: [Branch] = []
    public private(set) var remoteBranches: [Branch] = []
    public private(set) var stagedChanges: [FileChange] = []
    public private(set) var unstagedChanges: [FileChange] = []
    public private(set) var conflictedChanges: [FileChange] = []
    public private(set) var detachedHead: Commit?
    public private(set) var localBranchTree: [BranchNode] = []
    public private(set) var remoteBranchTree: [BranchNode] = []
    public private(set) var remoteSections: [RemoteSection] = []
    public internal(set) var visibleUnstagedChanges: [FileChange] = [] {
        didSet { rebuildChangeRows(staged: false) }
    }
    public internal(set) var visibleStagedChanges: [FileChange] = [] {
        didSet { rebuildChangeRows(staged: true) }
    }
    public internal(set) var stagingTick = 0
    public var changesListMode: FileListMode = .flat {
        didSet {
            guard changesListMode != oldValue else { return }
            rebuildChangeRows(staged: false)
            rebuildChangeRows(staged: true)
        }
    }
    public internal(set) var collapsedUnstagedFolders: Set<String> = [] {
        didSet { if collapsedUnstagedFolders != oldValue { rebuildChangeRows(staged: false) } }
    }
    public internal(set) var collapsedStagedFolders: Set<String> = [] {
        didSet { if collapsedStagedFolders != oldValue { rebuildChangeRows(staged: true) } }
    }
    public internal(set) var unstagedChangeRows: [FileListRow<FileChange>] = []
    public internal(set) var stagedChangeRows: [FileListRow<FileChange>] = []
    public internal(set) var selectedUnstagedRowIDs: Set<String> = []
    public internal(set) var selectedStagedRowIDs: Set<String> = []
    @ObservationIgnored var stagingMoves: [String: StagingMove] = [:]
    public private(set) var visibleConflictedChanges: [FileChange] = []
    public private(set) var isLoadingMoreHistory = false
    public private(set) var isFilteringBranches = false
    public private(set) var prefersCollapsedBranchFolders = false
    internal private(set) var historyRowModels: [HistoryRowModel] = []
    public private(set) var detail: Detail = .empty
    internal private(set) var diffDocument: DiffDocument?
    public internal(set) var isPreviewingFile = false
    public internal(set) var isPreviewingCommit = false
    public internal(set) var conflictWindowPath: String?
    @ObservationIgnored var conflictWindowOrder: [String] = []
    public private(set) var submodulePointerSummary: String?
    public private(set) var showsLargeDiff = false
    public private(set) var commitInfo: CommitInfo = .empty {
        didSet {
            switch commitInfo {
            case let .loaded(summary):
                previousCommitSummary = summary
                commitMessages.remember(summary.message, for: summary.commit.hash)
            case .empty, .failed: previousCommitSummary = nil
            case .loading: break
            }
            rebuildCommitFileRows()
            rebuildCommitTabRows()
        }
    }
    private var previousCommitSummary: CommitSummary?
    public var listedCommitSummary: CommitSummary? {
        switch commitInfo {
        case let .loaded(summary): summary
        case .loading: previousCommitSummary
        case .empty, .failed: nil
        }
    }
    public var isListedCommitSummaryStale: Bool {
        if case .loading = commitInfo { return previousCommitSummary != nil }
        return false
    }
    public var isBusy: Bool { runningActions > 0 }
    public var showsActivity: Bool { isBusy || pendingReads > 0 || isLocating || isLoading }
    public private(set) var hasLoaded = false
    public private(set) var isLoading = false
    public internal(set) var isLocating = false
    public private(set) var operations: Set<Operation> = []
    public var pane: Pane = .changes {
        didSet { if pane != .history, sidebarItem != nil { sidebarItem = nil } }
    }
    public internal(set) var sidebarItem: SidebarSelection?
    public var commitSubject = ""
    public var commitDescription = ""
    public var changesFilter = "" {
        didSet { if changesFilter != oldValue { scheduleFilters() } }
    }
    public var changeListOptions = ChangeListOptions() {
        didSet {
            guard changeListOptions != oldValue else { return }
            if changeListOptions.showsIgnored, !oldValue.showsIgnored {
                Task { await refresh(reportingErrors: false) }
            } else {
                if !changeListOptions.showsIgnored { ignoredChanges = [] }
                scheduleFilters()
            }
        }
    }
    @ObservationIgnored var ignoredChanges: [FileChange] = []
    public var branchFilter = "" {
        didSet { if branchFilter != oldValue { scheduleFilters() } }
    }
    public var sheet: Sheet?
    public var errorMessage: String? {
        didSet { if errorMessage != oldValue { hiddenFilesInError = [] } }
    }
    public private(set) var hiddenFilesInError: [String] = []
    public internal(set) var selectedCommitHashes: Set<String> = []
    var multiSelectionRows: [HistoryRowModel] = []
    public internal(set) var multiCommitDiffTarget: MultiCommitDiffTarget = .checking
    public let rangeChanges: CommitRangeChangesViewModel
    @ObservationIgnored var isSelectingCommits = false
    @ObservationIgnored var selectionAnchor: String?
    @ObservationIgnored var isMultiSelectionConsecutive = false
    @ObservationIgnored var rangeChecks: [String: CommitRange?] = [:]
    @ObservationIgnored var rangeCheckTask: Task<Void, Never>?
    public var selection: Selection? {
        didSet {
            guard oldValue != selection else { return }
            if isListedCommitSummaryStale, case let .commitFile(commit, _) = selection, commit == previousCommitSummary?.commit {
                selection = oldValue
                return
            }
            if case let .file(change, staged) = selection, isHiddenInChanges(change.path, staged: staged) {
                selection = nil
                return
            }
            syncSelectedChangeRows()
            if !isSelectingCommits { syncCommitSelection(from: oldValue) }
            if case let .commitFile(_, file) = selection { lastChangesFilePath = file.path }
            showsLargeDiff = false
            if selectedFilePath == nil { isPreviewingFile = false }
            followSelectionInConflictWindow()
            if selectedCommit == nil { isPreviewingCommit = false }
            clearLineSelection()
            reloadDetail()
            if Self.commit(of: oldValue) != selectedCommit {
                resetInlineDiffs()
                if !isMultiCommitSelection { reloadCommitInfo() }
                if commitDetailsTab == .fileTree, !isMultiCommitSelection { showFileTree() }
            }
            autoSelectChangesFile()
            prefetchChangeNeighbors()
        }
    }
    public var commitDetailsTab: CommitDetailsTab = .commit {
        didSet {
            guard commitDetailsTab != oldValue else { return }
            onCommitDetailsTabChange?(commitDetailsTab)
            showCommitDetailsTab()
        }
    }
    @ObservationIgnored var onCommitDetailsTabChange: ((CommitDetailsTab) -> Void)?
    @ObservationIgnored public var onDiffSettingsChange: ((DiffSettings) -> Void)?
    @ObservationIgnored public var onOpenWorktree: ((Worktree) async -> Void)?
    public internal(set) var fileTree: CommitTreeViewModel?
    public var commitFileFilter = "" {
        didSet { if commitFileFilter != oldValue { rebuildCommitFileRows() } }
    }
    public var commitFileListMode: FileListMode = .flat {
        didSet { if commitFileListMode != oldValue { rebuildCommitFileRows() } }
    }
    public internal(set) var commitFileRows: [CommitFileListRow] = []
    @ObservationIgnored var commitFileRowsSource: CommitFileRowsSource?
    @ObservationIgnored var lastChangesFilePath: String?
    var commitTabRows: [CommitTabRow] = []
    public internal(set) var areAllInlineDiffsExpanded = false
    @ObservationIgnored var inlineDiffs = InlineDiffs()
    @ObservationIgnored var inlineTasks: [UUID: Task<Void, Never>] = [:]
    public private(set) var commitWebLink: CommitWebLink?

    public private(set) var isAmending = false
    public internal(set) var commitTemplate: CommitTemplate?
    @ObservationIgnored var prefilledMessage: CommitMessage?
    @ObservationIgnored var amendMessage: (filled: CommitMessage, previous: CommitMessage)?
    @ObservationIgnored var commitTemplateTask: Task<Void, Never>?
    public var searchText = "" {
        didSet { if searchText != oldValue { scheduleSearch() } }
    }
    public var searchMode: CommitSearchMode = .message {
        didSet { if searchMode != oldValue { scheduleSearch() } }
    }
    public internal(set) var search = SearchState()
    internal var searchRows: [HistoryRowModel]?
    internal var searchGraphLanes = 1
    internal private(set) var historyGraphLanes = 1
    public internal(set) var searchFocusRequest = 0
    public private(set) var branchPickerRequest = 0
    public internal(set) var historyOptions: HistoryOptions
    public internal(set) var sidebarOptions: SidebarOptions
    public internal(set) var scrollRequest: ScrollRequest?
    public internal(set) var reflog: Loadable<[ReflogEntry]> = .idle
    public var fileInspector: FileInspector?
    public internal(set) var inspection = FileInspection()
    public internal(set) var conflictResolver: ConflictResolverViewModel?
    @ObservationIgnored var conflictResolvers: [String: ConflictResolverViewModel] = [:]
    public internal(set) var lineSelection = DiffLineSelection() {
        didSet { lineSelectionHasChanges = patch.map { lineSelection.hasChanges(in: $0) } ?? false }
    }
    public internal(set) var lineSelectionHasChanges = false
    public var ignoreDraft: IgnoreDraft?
    public var patchSession: ApplyPatchViewModel?
    public var notice: Notice?
    public var showsRawDiff = false
    public internal(set) var submoduleUpdate = SubmoduleUpdate()
    public var bisectLog: BisectLogText?
    public var statistics: StatisticsViewModel?
    public internal(set) var imageDiff: ImageDiffViewModel?
    public var pendingBranchDrop: BranchDropRequest?
    public var pendingForceDeletion: BranchForceDeletion?
    public internal(set) var settings: AppSettings = .standard
    public var repositorySettings: RepositorySettingsViewModel?
    public let externalTools = ExternalToolRuns()
    public let signatureBadges = SignatureBadgeStore()
    public let commitMessages = CommitMessageStore()
    let preloader = CommitPreloader(capacity: RepositoryViewModel.commitPreloadCapacity, byteBudget: RepositoryViewModel.commitPreloadByteBudget)
    let workingDiffs = WorkingCopyDiffCache(capacity: RepositoryViewModel.commitPreloadCapacity)
    public let advanced = AdvancedTools()
    public internal(set) var customCommandMenus: [CustomCommandLocation: [CustomCommand]] = [:]
    public var pendingCustomCommand: PendingCustomCommand?

    let dependencies: RepositoryDependencies
    let searchDebounce: Duration
    let sleep: @Sendable (Duration) async throws -> Void
    let now: @Sendable () -> ContinuousClock.Instant
    @ObservationIgnored let explorationTasks = ExplorationTasks()
    @ObservationIgnored let autoFetch = AutoFetchState()
    @ObservationIgnored var backgroundFetch: Task<Void, Never>?
    @ObservationIgnored var lineAnchor: DiffLineID?
    @ObservationIgnored var lineDragStart: DiffLineID?
    @ObservationIgnored var lineDragBase = DiffLineSelection()
    private var detailTask: Task<Void, Never>?
    private var commitInfoTask: Task<Void, Never>?
    private var loadedPatch: (selection: Selection, patch: FilePatch)?
    @ObservationIgnored private var isDetailDeferred = false
    private var runningActions = 0
    private var pendingReads = 0
    @ObservationIgnored let filterDebounce: Duration
    @ObservationIgnored var presentation = RepositoryPresentation()
    @ObservationIgnored var presentationVersion = 0
    @ObservationIgnored var sidebarTask: Task<Void, Never>?
    @ObservationIgnored private var refreshLoop: Task<Void, Never>?
    @ObservationIgnored private var refreshRequested = false
    @ObservationIgnored private var refreshReportsErrors = false
    @ObservationIgnored private var filterTask: Task<Void, Never>?
    @ObservationIgnored private var historyPageTask: Task<Void, Never>?
    @ObservationIgnored private var isAppActive = true
    @ObservationIgnored private var changedWhileInactive = false
    private var changedDuringAction = false
    @ObservationIgnored private let watch = WatchSubscription()

    public init(
        url: URL,
        dependencies: RepositoryDependencies,
        searchDebounce: Duration = .milliseconds(300),
        filterDebounce: Duration = .milliseconds(150),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        now: @escaping @Sendable () -> ContinuousClock.Instant = { ContinuousClock.now }
    ) {
        self.url = url
        self.dependencies = dependencies
        self.searchDebounce = searchDebounce
        self.filterDebounce = filterDebounce
        self.sleep = sleep
        self.now = now
        rangeChanges = CommitRangeChangesViewModel(loadChanges: dependencies.range.loadChanges, loadDiff: dependencies.range.loadDiff)
        sidebarOptions = dependencies.sidebarOptions.load.execute(repository: url)
        historyOptions = dependencies.exploration.loadHistoryOptions.execute(repository: url)
    }

    public var name: String { url.lastPathComponent }
    public var commitMessage: CommitMessage { CommitMessage(subject: commitSubject, description: commitDescription) }
    public var isSubjectTooLong: Bool { commitMessage.isSubjectTooLong }
    public var canCommit: Bool {
        !effectiveCommitMessage.isEmpty && (isAmending || !stagedChanges.isEmpty)
    }

    public var snapshot: RepositorySnapshot { presentation.snapshot }
    public var selectedCommit: Commit? { Self.commit(of: selection) }

    public var patch: FilePatch? {
        guard let loadedPatch, loadedPatch.selection == selection else { return nil }
        return loadedPatch.patch
    }

    public var hunkActions: [HunkAction] {
        guard case let .file(change, staged) = selection, patch?.hunks.isEmpty == false else { return [] }
        return HunkAction.available(for: change, staged: staged)
    }

    public var isWatching: Bool { watch.task != nil }

    public func startWatching() {
        guard watch.task == nil else { return }
        let changes = dependencies.watchRepository.execute(root: url)
        watch.task = Task { [weak self] in
            for await _ in changes {
                await self?.refreshAfterExternalChange()
            }
        }
    }

    public func stopWatching() {
        watch.cancel()
    }

    public func releaseMemory() {
        preloader.releaseMemory()
        workingDiffs.clear()
        rangeChanges.releaseMemory()
    }

    public func refresh(reportingErrors: Bool = true) async {
        refreshRequested = true
        refreshReportsErrors = refreshReportsErrors || reportingErrors
        if let refreshLoop {
            await refreshLoop.value
            return
        }
        let loop = Task { await runRefreshLoop() }
        refreshLoop = loop
        await loop.value
    }

    private func runRefreshLoop() async {
        while refreshRequested {
            refreshRequested = false
            let reportingErrors = refreshReportsErrors
            refreshReportsErrors = false
            await refreshOnce(reportingErrors: reportingErrors)
        }
        refreshLoop = nil
    }

    private func refreshOnce(reportingErrors: Bool) async {
        workingDiffs.clear()
        if !hasLoaded {
            isLoading = true
            startLoadingCommitTemplate()
        }
        historyPageTask?.cancel()
        historyPageTask = nil
        isLoadingMoreHistory = false
        do {
            let limit = max(Self.historyLimit, presentation.snapshot.historyCursor.loadedCommits.roundedUp(to: Self.historyLimit))
            let amending = isAmending
            async let ignored = Self.ignoredFiles(showing: changeListOptions.showsIgnored, dependencies: dependencies)
            async let amended = amending ? dependencies.commit.loadWorkingCopyChanges.execute(amending: true) : nil
            var loaded = try await dependencies.loadSnapshot.execute(historyLimit: limit, options: historyOptions)
            if let amended = try await amended { loaded = loaded.replacingChanges(amended) }
            if amending != isAmending {
                loaded = loaded.replacingChanges(presentation.snapshot.changes)
                refreshRequested = true
            }
            ignoredChanges = await ignored
            if hasLoaded, let branch = loaded.branches.first(where: \.isCurrent), branch.fullName != currentBranch?.fullName {
                rememberBranch(branch, among: loaded.branches)
            }
            await present(loaded)
            if isSearchActive { scheduleSearch() }
        } catch {
            if reportingErrors, !refreshRequested { errorMessage = error.localizedDescription }
        }
        let isFirstLoad = !hasLoaded
        hasLoaded = true
        if isLoading { isLoading = false }
        reconcileSelection()
        advanceConflictWindow()
        reconcileSidebarItem()
        if isFirstLoad, isAutoFetching, autoFetch.lastAttempt == nil { restartAutoFetch() }
        if pane == .reflog { await loadReflog() }
    }

    func present(_ snapshot: RepositorySnapshot) async {
        while true {
            let previous = presentation
            let version = presentationVersion
            let branchFilter = branchFilter
            let changesFilter = changesFilter
            let changeListOptions = changeListOptions
            let ignored = changeListOptions.showsIgnored ? ignoredChanges : []
            let options = historyOptions
            let sidebarOptions = sidebarOptions
            let (next, changed) = await Task.detached(priority: .userInitiated) {
                RepositoryPresentation.present(snapshot, after: previous, branchFilter: branchFilter, changesFilter: changesFilter, changeListOptions: changeListOptions, ignored: ignored, options: options, sidebarOptions: sidebarOptions)
            }.value
            guard version == presentationVersion else { continue }
            apply(next, changed)
            return
        }
    }

    func apply(_ next: RepositoryPresentation, _ changed: PresentationChanges) {
        let snapshot = next.snapshot
        if changed.contains(.branches) {
            if !prefersCollapsedBranchFolders, snapshot.branches.count > BranchOutline.collapseThreshold { prefersCollapsedBranchFolders = true }
            branches = snapshot.branches
            currentBranch = next.currentBranch
            localBranches = next.localBranches
            remoteBranches = next.remoteBranches
        }
        if changed.contains(.changes) {
            changes = snapshot.changes
            hasTabChanges = snapshot.changes.contains { !$0.isIgnored }
            stagedChanges = next.stagedChanges
            unstagedChanges = next.unstagedChanges
            conflictedChanges = next.conflictedChanges
            scheduleLFSMarkers()
        }
        if changed.contains(.history) { historyRows = snapshot.history }
        if detachedHead != next.detachedHead { detachedHead = next.detachedHead }
        if changed.contains(.stashes) { stashes = snapshot.stashes }
        if changed.contains(.tags) {
            tags = snapshot.tags
            rebuildTagSidebarRows()
        }
        if changed.contains(.state) { repositoryState = snapshot.state }
        if changed.contains(.remotes) {
            remotes = snapshot.remotes
            let link = CommitWebLink.preferred(in: snapshot.remotes)
            if link != commitWebLink { commitWebLink = link }
        }
        if changed.contains(.worktrees) { worktrees = snapshot.worktrees }
        if changed.contains(.submodules) { submodules = snapshot.submodules }
        if changed.contains(.bisect) { bisectSession = snapshot.bisect }
        if changed.contains(.branchLists) {
            localBranchTree = next.branchLists.localTree
            remoteBranchTree = next.branchLists.remoteTree
            remoteSections = next.branchLists.remoteSections
        }
        let filtering = !next.branchLists.filter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if isFilteringBranches != filtering { isFilteringBranches = filtering }
        if changed.contains(.changeLists) {
            visibleConflictedChanges = next.changeLists.conflicted
        }
        if changed.contains(.rows) {
            historyRowModels = next.rows
            if historyGraphLanes != next.graphLanes { historyGraphLanes = next.graphLanes }
        }
        presentation = next
        if changed.contains(.changeLists) {
            if stagingMoves.isEmpty {
                if visibleUnstagedChanges != next.changeLists.unstaged { visibleUnstagedChanges = next.changeLists.unstaged }
                if visibleStagedChanges != next.changeLists.staged { visibleStagedChanges = next.changeLists.staged }
            } else {
                refreshVisibleChanges(animated: false)
            }
        }
        presentationVersion += 1
    }

    public func waitForFilters() async {
        await filterTask?.value
    }

    func scheduleFilters() {
        filterTask?.cancel()
        let debounce = filterDebounce
        filterTask = Task { [weak self] in
            if debounce > .zero {
                do { try await Task.sleep(for: debounce) } catch { return }
            }
            guard let self, !Task.isCancelled else { return }
            await self.present(self.presentation.snapshot)
        }
    }

    public var hasMoreHistory: Bool { !presentation.snapshot.historyCursor.isComplete && !isSearchActive }

    public func loadMoreHistoryIfNeeded(after row: String) {
        guard hasMoreHistory, historyPageTask == nil, refreshLoop == nil,
              let index = presentation.historyIndex[row], index >= historyRows.count - Self.historyPrefetchDistance else { return }
        loadMoreHistory()
    }

    public func loadMoreHistory() {
        guard hasMoreHistory, historyPageTask == nil else { return }
        isLoadingMoreHistory = true
        let cursor = presentation.snapshot.historyCursor
        let options = historyOptions
        let version = presentationVersion
        let loadPage = dependencies.loadHistoryPage
        historyPageTask = Task { [weak self] in
            let page = try? await loadPage.execute(after: cursor, limit: Self.historyLimit, options: options)
            guard let self, !Task.isCancelled else { return }
            defer {
                self.historyPageTask = nil
                self.isLoadingMoreHistory = false
            }
            guard let page, version == self.presentationVersion else { return }
            let current = self.presentation
            let next = await Task.detached(priority: .userInitiated) { current.appending(page, options: options) }.value
            guard version == self.presentationVersion, !Task.isCancelled else { return }
            self.apply(next, page.rows.isEmpty ? [.history] : [.history, .rows])
        }
    }

    public func waitForHistoryPage() async {
        await historyPageTask?.value
    }

    public func stage(_ change: FileChange) async {
        guard !change.isConflicted else {
            await perform { try await $0.stageFiles.execute(paths: [change.path]) }
            return
        }
        await moveStaging([change], toStaged: true)
    }

    public func unstage(_ change: FileChange) async {
        await moveStaging([change], toStaged: false)
    }

    public func toggleStaging(_ items: Set<Selection>) async {
        var stage: [FileChange] = []
        var unstage: [FileChange] = []
        for item in items {
            guard case let .file(change, staged) = item, !change.isConflicted else { continue }
            if staged { unstage.append(change) } else { stage.append(change) }
        }
        await moveStaging(stage, toStaged: true)
        await moveStaging(unstage, toStaged: false)
    }

    nonisolated static func ignoredFiles(showing: Bool, dependencies: RepositoryDependencies) async -> [FileChange] {
        guard showing else { return [] }
        return (try? await dependencies.tools.loadIgnoredFiles.execute()) ?? []
    }

    public func stageAll() async {
        await moveStaging(unstagedChanges, toStaged: true) { try await $0.stageAllChanges.execute() }
    }

    public func unstageAll() async {
        let paths = stagedChanges.map(\.path)
        let amending = isAmending
        await moveStaging(stagedChanges, toStaged: false) { try await $0.unstage(paths: paths, amending: amending) }
    }

    public func discard(_ change: FileChange) async {
        await discard([change])
    }

    public func discard(_ changes: [FileChange]) async {
        guard !changes.isEmpty else { return }
        await perform { dependencies in
            for change in changes {
                try await dependencies.discardFileChanges.execute(change: change)
            }
        }
    }

    public func setAmending(_ amending: Bool) async {
        guard amending != isAmending else { return }
        isAmending = amending
        if !amending { restoreMessageBeforeAmend() }
        let dependencies = dependencies
        let fillsMessage = amending && isComposerUntouched
        async let changes = Self.workingCopyChanges(amending: amending, dependencies: dependencies)
        async let lastMessage = fillsMessage ? Self.lastCommitMessage(dependencies) : nil
        let (loadedChanges, loadedMessage) = await (changes, lastMessage)
        guard isAmending == amending else { return }
        switch loadedMessage {
        case let .success(text):
            if isComposerUntouched { fillAmendMessage(CommitMessage(parsing: text ?? "")) }
        case let .failure(error):
            errorMessage = error.localizedDescription
        case nil:
            break
        }
        guard let loadedChanges else {
            await refresh()
            return
        }
        workingDiffs.clear()
        await present(presentation.snapshot.replacingChanges(loadedChanges))
        stagingTick &+= 1
        reconcileSelection()
    }

    private func fillAmendMessage(_ last: CommitMessage) {
        amendMessage = (filled: last, previous: commitMessage)
        commitSubject = last.subject
        commitDescription = last.description
    }

    private func restoreMessageBeforeAmend() {
        guard let amendMessage else { return }
        self.amendMessage = nil
        guard commitMessage == amendMessage.filled else { return }
        commitSubject = amendMessage.previous.subject
        commitDescription = amendMessage.previous.description
    }

    nonisolated static func workingCopyChanges(amending: Bool, dependencies: RepositoryDependencies) async -> [FileChange]? {
        try? await dependencies.commit.loadWorkingCopyChanges.execute(amending: amending)
    }

    nonisolated static func lastCommitMessage(_ dependencies: RepositoryDependencies) async -> Result<String?, Error> {
        do {
            return .success(try await dependencies.loadLastCommitMessage.execute())
        } catch {
            return .failure(error)
        }
    }

    public func commit() async {
        let message = commitMessage.text
        let amend = isAmending
        let committed = await perform { dependencies in
            try await dependencies.commitChanges.execute(message: message, amend: amend)
            isAmending = false
        }
        if committed {
            commitSubject = ""
            commitDescription = ""
            amendMessage = nil
            prefillCommitTemplate()
        }
    }

    public func abortMerge() async {
        await perform { try await $0.abortMerge.execute() }
    }

    @discardableResult
    public func createBranch(named name: String) async -> Bool {
        await perform { try await $0.createBranch.execute(name: name) }
    }

    public func checkout(_ branch: Branch) async {
        let localName = branch.isRemote ? branch.localName : branch.name
        if let worktree = worktrees.first(where: { !$0.isBare && !$0.isPrunable && $0.branch == localName && !$0.isLocated(at: url) }),
           let onOpenWorktree {
            await onOpenWorktree(worktree)
            return
        }
        await perform { try await $0.checkoutBranch.execute(branch: branch) }
    }

    public func delete(_ branch: Branch, force: Bool, alsoDeleteRemote: Bool = false) async {
        let remote = alsoDeleteRemote ? remoteBranchForDeletion(of: branch) : nil
        var refusal: BranchDeletionError?
        await perform { dependencies in
            if let remote {
                try await dependencies.workspace.remotes.deleteRemoteBranch.ensureDeletable(branch: remote)
            }
            do {
                try await dependencies.deleteBranch.execute(branch: branch, force: force)
            } catch let error as BranchDeletionError {
                refusal = error
                return
            }
            if let remote {
                do {
                    try await dependencies.workspace.remotes.deleteRemoteBranch.execute(branch: remote)
                } catch {
                    throw NSError(domain: "BranchDeletion", code: 1, userInfo: [NSLocalizedDescriptionKey:
                        "The local branch '\(branch.name)' was deleted, but deleting '\(remote.name)' on the server failed: \(error.localizedDescription)"])
                }
            }
        }
        if let refusal {
            pendingForceDeletion = BranchForceDeletion(branch: branch, alsoDeleteRemote: alsoDeleteRemote, reason: refusal.localizedDescription)
        }
    }

    public func forceDelete(_ deletion: BranchForceDeletion) async {
        pendingForceDeletion = nil
        await delete(deletion.branch, force: true, alsoDeleteRemote: deletion.alsoDeleteRemote)
    }

    public func merge(_ branch: Branch) async {
        await perform { try await $0.mergeBranch.execute(branch: branch) }
    }

    public func fetch() async {
        await tracking(.fetch) { _ = await perform { try await $0.fetchRemotes.execute() } }
    }

    public func pull() async {
        let branch = currentBranch
        await tracking(.pull) {
            if await perform({ try await $0.pullBranch.execute(branch: branch) }) { fetchAllInBackground() }
        }
    }

    public func push() async {
        let branch = currentBranch
        await tracking(.push) { _ = await perform { try await $0.pushBranch.execute(branch: branch) } }
    }

    public func reload() async {
        await tracking(.refresh) { await refresh() }
    }

    public func requestBranchPicker() {
        branchPickerRequest += 1
    }

    public func isRunning(_ operation: Operation) -> Bool {
        operations.contains(operation)
    }

    @discardableResult
    public func stash(message: String) async -> Bool {
        await perform { try await $0.stashChanges.execute(message: message) }
    }

    public func apply(_ stash: Stash, drop: Bool) async {
        await perform { try await $0.applyStash.execute(stash: stash, drop: drop) }
    }

    public func drop(_ stash: Stash) async {
        await perform { try await $0.dropStash.execute(stash: stash) }
    }

    @discardableResult
    public func createTag(named name: String, message: String) async -> Bool {
        await perform { try await $0.createTag.execute(name: name, message: message) }
    }

    public func delete(_ tag: Tag) async {
        await perform { try await $0.deleteTag.execute(tag: tag) }
    }

    public func runCommand(_ commandLine: String) async {
        await perform { try await $0.runGitCommand.execute(commandLine: commandLine) }
    }

    public func apply(_ action: HunkAction, to hunk: DiffHunk) async {
        guard case let .file(change, _) = selection, let patch, hunkActions.contains(action) else { return }
        await perform { try await $0.applyHunk.execute(action: action, hunk: hunk, patch: patch, change: change) }
    }

    public func unhide(_ paths: [String]) async {
        await perform { try await $0.tools.unhideFiles.execute(paths: paths) }
    }

    public func waitForDetail() async {
        await detailTask?.value
        await commitInfoTask?.value
    }

    @discardableResult
    func perform(_ action: (RepositoryDependencies) async throws -> Void) async -> Bool {
        runningActions += 1
        defer { runningActions -= 1 }
        workingDiffs.clear()
        let stateBefore = repositoryState
        var failure: Error?
        do {
            try await action(dependencies)
        } catch {
            failure = error
        }
        changedDuringAction = false
        await refresh()
        if changedDuringAction {
            changedDuringAction = false
            await refresh(reportingErrors: false)
        }
        guard let failure else { return true }
        let stoppedOnConflicts = stateBefore == .clean && repositoryState != .clean && !conflictedChanges.isEmpty
        if !stoppedOnConflicts {
            let message = failure.localizedDescription
            let hidden = (try? await dependencies.tools.findHiddenFiles.execute(failureMessage: message)) ?? []
            errorMessage = message
            hiddenFilesInError = hidden
        }
        return false
    }

    func reading<T>(_ body: () async throws -> T) async rethrows -> T {
        pendingReads += 1
        defer { pendingReads -= 1 }
        return try await body()
    }

    func tracking(_ operation: Operation, _ body: () async -> Void) async {
        guard operations.insert(operation).inserted else { return }
        await body()
        operations.remove(operation)
    }

    public func setAppActive(_ active: Bool) {
        guard isAppActive != active else { return }
        isAppActive = active
        if active, isAutoFetching { restartAutoFetch() }
        guard active, changedWhileInactive else { return }
        changedWhileInactive = false
        Task { await refresh(reportingErrors: false) }
    }

    private func refreshAfterExternalChange() async {
        guard isAppActive else {
            changedWhileInactive = true
            return
        }
        guard !isBusy else {
            changedDuringAction = true
            return
        }
        await refresh(reportingErrors: false)
    }

    private func reconcileSelection() {
        switch selection {
        case let .file(change, staged):
            let list = staged ? stagedChanges : unstagedChanges
            if let updated = list.first(where: { $0.path == change.path }) {
                if updated == change { reloadDetail() } else { selection = .file(updated, staged: staged) }
            } else {
                selection = nil
            }
        case let .commit(commit), let .commitFile(commit, _):
            if !isKnown(commit) {
                selection = nil
            } else if isMultiCommitSelection {
                reconcileMultiSelection()
            }
        case nil:
            break
        }
    }

    func reloadDetail() {
        detailTask?.cancel()
        refreshImageDiff()
        if showConflictResolver() {
            clearDetail()
            return
        }
        guard let selection else {
            clearDetail()
            return
        }
        if case .commit = selection, commitDetailsTab != .changes || isMultiCommitSelection {
            isDetailDeferred = true
            return
        }
        isDetailDeferred = false
        if case let .commit(commit) = selection, !showsLargeDiff {
            reloadCommitDetail(commit, selection: selection)
            return
        }
        if case let .commitFile(commit, file) = selection, !showsLargeDiff, reloadFromWholeCommit(commit, file: file, selection: selection) {
            return
        }
        if case let .file(change, staged) = selection, !showsLargeDiff {
            reloadFileDetail(WorkingCopyDiffCache.Key(change: change, staged: staged), selection: selection)
            return
        }
        loadDetail(selection)
    }

    struct DetailRequest: Sendable {
        let selection: Selection
        let dependencies: RepositoryDependencies
        let tabWidth: Int
        let showsLarge: Bool
        let path: String?
        let amending: Bool
    }

    struct LoadedDetail: Sendable {
        let result: Detail
        let prepared: (patch: FilePatch?, document: DiffDocument, summary: String?, lfs: LFSPointerChange?)?
    }

    func detailRequest(_ selection: Selection) -> DetailRequest {
        DetailRequest(selection: selection, dependencies: dependencies, tabWidth: settings.diff.tabWidth, showsLarge: showsLargeDiff, path: selectedFilePath, amending: isAmending)
    }

    private func loadDetail(_ selection: Selection) {
        if detail == .empty { detail = .loading }
        let request = detailRequest(selection)
        detailTask = Task { [weak self] in
            let loaded = await Self.fetchDetail(request)
            guard !Task.isCancelled, let self, self.selection == selection else { return }
            self.apply(loaded, for: selection)
        }
    }

    nonisolated static func fetchDetail(_ request: DetailRequest) async -> LoadedDetail {
        let selection = request.selection
        let dependencies = request.dependencies
        do {
            let text: String
            var isFile = false
            var usesPatch = false
            switch selection {
            case let .file(change, staged):
                text = try await staged && request.amending
                    ? dependencies.commit.loadAmendDiff.execute(change: change)
                    : dependencies.loadFileDiff.execute(change: change, staged: staged)
                isFile = true
                usesPatch = !HunkAction.available(for: change, staged: staged).isEmpty
            case let .commit(commit):
                text = try await dependencies.loadCommitDetails.execute(commit: commit)
            case let .commitFile(commit, file):
                text = try await dependencies.loadCommitFileDiff.execute(commit: commit, file: file)
            }
            let isCommit = if case .commit = selection { true } else { false }
            let tabWidth = request.tabWidth
            let showsLarge = request.showsLarge
            let path = request.path
            let prepared = await Task.detached(priority: .userInitiated) {
                let patch = isFile ? DiffParser.parse(text).first : nil
                let usable = patch.flatMap { usesPatch && !$0.hunks.isEmpty ? $0 : nil }
                let document = DiffDocument.make(text: text, patch: usable, isCommit: isCommit, tabWidth: tabWidth, showsLarge: showsLarge)
                return (patch, document, Self.submoduleSummary(of: text, path: path), Self.lfsPointerChange(of: text))
            }.value
            return LoadedDetail(result: .loaded(text), prepared: prepared)
        } catch {
            return LoadedDetail(result: .failed(error.localizedDescription), prepared: nil)
        }
    }

    private func apply(_ loaded: LoadedDetail, for selection: Selection) {
        let prepared = loaded.prepared
        let previous = patch
        detail = loaded.result
        loadedPatch = prepared?.patch.map { (selection, $0) }
        if diffDocument != prepared?.document { diffDocument = prepared?.document }
        if submodulePointerSummary != prepared?.summary { submodulePointerSummary = prepared?.summary }
        if advanced.lfsPointer != prepared?.lfs { advanced.lfsPointer = prepared?.lfs }
        if patch != previous { clearLineSelection() }
    }

    private func reloadFileDetail(_ key: WorkingCopyDiffCache.Key, selection: Selection) {
        if let ready = workingDiffs.detail(of: key) {
            detailTask = nil
            apply(ready, for: selection)
            return
        }
        if detail == .empty { detail = .loading }
        let task = workingDiffTask(for: key)
        detailTask = Task { [weak self] in
            let loaded = await task.value
            guard !Task.isCancelled, let self, self.selection == selection else { return }
            self.apply(loaded, for: selection)
        }
    }

    private func reloadCommitDetail(_ commit: Commit, selection: Selection) {
        if let ready = preloader.detail(of: commit.hash, tabWidth: settings.diff.tabWidth) {
            detailTask = nil
            applyPreparedDetail(ready)
            return
        }
        if detail == .empty { detail = .loading }
        let task = commitDetailTask(for: commit)
        detailTask = Task { [weak self] in
            let result = await task.value
            guard !Task.isCancelled, let self, self.selection == selection else { return }
            switch result {
            case let .success(prepared): self.applyPreparedDetail(prepared)
            case let .failure(error):
                self.detail = .failed(error.localizedDescription)
                self.loadedPatch = nil
                self.diffDocument = nil
            }
        }
    }

    private func reloadFromWholeCommit(_ commit: Commit, file: CommitFileChange, selection: Selection) -> Bool {
        if let ready = preloader.detail(of: commit.hash, tabWidth: settings.diff.tabWidth) {
            guard let prepared = ready.files[file.path] else { return false }
            detailTask = nil
            applyPreparedFile(prepared)
            return true
        }
        guard let pending = preloader.pendingDetail(of: commit.hash) else { return false }
        if detail == .empty { detail = .loading }
        detailTask = Task { [weak self] in
            let result = await pending.value
            guard !Task.isCancelled, let self, self.selection == selection else { return }
            if case let .success(ready) = result, let prepared = ready.files[file.path] {
                self.applyPreparedFile(prepared)
                return
            }
            let loaded = await Self.fetchDetail(self.detailRequest(selection))
            guard !Task.isCancelled, self.selection == selection else { return }
            self.apply(loaded, for: selection)
        }
        return true
    }

    private func applyPreparedFile(_ prepared: CommitPreloader.PreparedFile) {
        let previous = patch
        detail = .loaded(prepared.text)
        loadedPatch = nil
        if diffDocument != prepared.document { diffDocument = prepared.document }
        if submodulePointerSummary != prepared.submoduleSummary { submodulePointerSummary = prepared.submoduleSummary }
        if advanced.lfsPointer != prepared.lfsPointer { advanced.lfsPointer = prepared.lfsPointer }
        if patch != previous { clearLineSelection() }
    }

    private func applyPreparedDetail(_ prepared: CommitPreloader.PreparedDetail) {
        let previous = patch
        detail = .loaded(prepared.text)
        loadedPatch = nil
        if diffDocument != prepared.document { diffDocument = prepared.document }
        if submodulePointerSummary != prepared.submoduleSummary { submodulePointerSummary = prepared.submoduleSummary }
        if advanced.lfsPointer != prepared.lfsPointer { advanced.lfsPointer = prepared.lfsPointer }
        if patch != previous { clearLineSelection() }
    }

    public func showLargeDiff() {
        guard !showsLargeDiff, selection != nil else { return }
        showsLargeDiff = true
        reloadDetail()
    }

    private func showCommitDetailsTab() {
        guard !isMultiCommitSelection else {
            showRangeChangesIfVisible()
            return
        }
        switch commitDetailsTab {
        case .commit:
            rebuildCommitTabRows()
        case .changes:
            rebuildCommitFileRows()
            autoSelectChangesFile()
            if isDetailDeferred { reloadDetail() }
            if let commit = selectedCommit { prefetchNeighbors(of: commit) }
        case .fileTree:
            showFileTree()
        }
    }

    private func clearDetail() {
        isDetailDeferred = false
        detail = .empty
        detailTask = nil
        loadedPatch = nil
        diffDocument = nil
        submodulePointerSummary = nil
        advanced.lfsPointer = nil
    }

    func reloadCommitInfo() {
        commitInfoTask?.cancel()
        guard let commit = selectedCommit else {
            commitInfo = .empty
            commitInfoTask = nil
            return
        }
        if let ready = preloader.summary(of: commit.hash) {
            commitInfo = .loaded(ready)
            commitInfoTask = nil
            prefetchNeighbors(of: commit)
            return
        }
        commitInfo = .loading
        let task = summaryTask(for: commit)
        commitInfoTask = Task { [weak self] in
            let result: CommitInfo
            switch await task.value {
            case let .success(summary): result = .loaded(summary)
            case let .failure(error): result = .failed(error.localizedDescription)
            }
            guard !Task.isCancelled, let self, self.selectedCommit == commit else { return }
            self.commitInfo = result
            self.prefetchNeighbors(of: commit)
            self.autoSelectChangesFile()
            let follow = self.detailTask
            await follow?.value
        }
    }

    static func commit(of selection: Selection?) -> Commit? {
        switch selection {
        case let .commit(commit), let .commitFile(commit, _): commit
        case .file, nil: nil
        }
    }
}

extension RepositoryViewModel: Identifiable {}

private extension Int {
    func roundedUp(to step: Int) -> Int {
        (self + step - 1) / step * step
    }
}

private final class WatchSubscription {
    var task: Task<Void, Never>?

    func cancel() {
        task?.cancel()
        task = nil
    }

    deinit {
        task?.cancel()
    }
}
