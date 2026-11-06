import MorkDomain
import Foundation

struct HistoryRowModel: Identifiable, Equatable, Sendable {
    let graph: GraphRow
    let labels: [RefLabel]
    let isHead: Bool
    let date: String
    let bisect: BisectBadgeKind?

    var id: String { graph.id }
    var commit: Commit { graph.commit }

    struct Context: Sendable {
        let remotes: Set<String>
        let options: HistoryOptions
        let bisect: BisectSession?
        let now: Date

        init(remoteBranches: [Branch], options: HistoryOptions, bisect: BisectSession?, now: Date = Date()) {
            remotes = Set(remoteBranches.compactMap(\.remoteName))
            self.options = options
            self.bisect = bisect
            self.now = now
        }

        func badge(for commit: Commit) -> BisectBadgeKind? {
            guard let bisect else { return nil }
            if bisect.firstBad?.hash == commit.hash { return .firstBad }
            if bisect.candidate?.hash == commit.hash { return .candidate }
            return switch bisect.marks[commit.hash] {
            case .good: .good
            case .bad: .bad
            case .skip: .skip
            case nil: nil
            }
        }
    }

    static func make(_ rows: [GraphRow], reusing previous: [HistoryRowModel], context: Context) -> [HistoryRowModel] {
        guard !previous.isEmpty else { return make(rows, context: context) }
        let known = Dictionary(previous.map { ($0.id, $0) }) { first, _ in first }
        var models: [HistoryRowModel] = []
        models.reserveCapacity(rows.count)
        var missing: [(Int, GraphRow)] = []
        for row in rows {
            if let model = known[row.id], model.graph == row {
                models.append(model)
            } else {
                missing.append((models.count, row))
                models.append(HistoryRowModel(graph: row, labels: [], isHead: false, date: "", bisect: nil))
            }
        }
        for (model, (index, _)) in zip(make(missing.map(\.1), context: context), missing) {
            models[index] = model
        }
        return models
    }

    static func make(_ rows: [GraphRow], context: Context) -> [HistoryRowModel] {
        let calendar = Calendar.current
        let locale = Locale.current
        return rows.map { row in
            let labels = RefLabel.labels(for: context.options.visibleRefs(of: row.commit), remotes: context.remotes)
            return HistoryRowModel(
                graph: row,
                labels: labels,
                isHead: row.commit.refNames.contains { $0 == "HEAD" || $0.hasPrefix("HEAD -> ") },
                date: CommitDateText.string(for: row.commit.date, now: context.now, calendar: calendar, locale: locale),
                bisect: context.badge(for: row.commit)
            )
        }
    }
}

struct BranchLists: Equatable, Sendable {
    var filter = ""
    var pinned: [String] = []
    var sortOrder: BranchSortOrder = .alphabeticalMainAndFoldersFirst
    var remoteSortOrder: BranchSortOrder = .alphabeticalMainAndFoldersFirst
    var localTree: [BranchNode] = []
    var remoteTree: [BranchNode] = []
    var remoteSections: [RemoteSection] = []

    static func make(local: [Branch], remote: [Branch], remotes: [Remote], filter: String, pinned: [String] = [], sortOrder: BranchSortOrder = .alphabeticalMainAndFoldersFirst, recent: [String] = [], remoteSortOrder: BranchSortOrder = .alphabeticalMainAndFoldersFirst, remoteRecent: [String] = []) -> BranchLists {
        let pinnedRefs = Set(pinned)
        let query = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        func pinnedLeaves(_ branches: [Branch], title: (Branch) -> String) -> [BranchNode] {
            branches
                .filter { pinnedRefs.contains($0.fullName) && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                .map { BranchNode(id: $0.fullName, name: title($0), branch: $0, children: []) }
        }
        let unpinnedRemote = remote.filter { !pinnedRefs.contains($0.fullName) }
        let remoteTree = BranchTree.build(unpinnedRemote, filter: filter).map { node in
            BranchNode(id: node.id, name: node.name, branch: node.branch, children: BranchSidebarSorting.sorted(node.children, order: remoteSortOrder, recent: remoteRecent))
        }
        let folders = Dictionary(remoteTree.filter { $0.branch == nil }.map { ($0.name, $0.children) }) { first, _ in first }
        let pinnedRemote = Dictionary(grouping: pinnedLeaves(remote, title: \.localName)) { $0.branch?.remoteName ?? "" }
        let byName = Dictionary(remotes.map { ($0.name, $0) }) { first, _ in first }
        let isFiltering = !query.isEmpty
        let names = Set(folders.keys).union(pinnedRemote.keys).union(isFiltering ? [] : Array(byName.keys))
        let sections = names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.map { name in
            RemoteSection(name: name, remote: byName[name], nodes: (pinnedRemote[name] ?? []) + (folders[name] ?? []))
        }
        let unpinnedLocal = BranchTree.build(local.filter { !pinnedRefs.contains($0.fullName) }, filter: filter)
        let localTree = pinnedLeaves(local, title: \.name) + BranchSidebarSorting.sorted(unpinnedLocal, order: sortOrder, recent: recent)
        return BranchLists(filter: filter, pinned: pinned, sortOrder: sortOrder, remoteSortOrder: remoteSortOrder, localTree: localTree, remoteTree: remoteTree, remoteSections: sections)
    }
}

public struct ChangeListOptions: Hashable, Sendable {
    public var hidesUntracked = false
    public var showsIgnored = false
    public var isCombined = false

    public init(hidesUntracked: Bool = false, showsIgnored: Bool = false, isCombined: Bool = false) {
        self.hidesUntracked = hidesUntracked
        self.showsIgnored = showsIgnored
        self.isCombined = isCombined
    }

    func admits(_ change: FileChange) -> Bool {
        if change.isUntracked { return !hidesUntracked }
        if change.isIgnored { return showsIgnored }
        return true
    }
}

struct ChangeLists: Equatable, Sendable {
    var filter = ""
    var options = ChangeListOptions()
    var ignored: [FileChange] = []
    var unstaged: [FileChange] = []
    var staged: [FileChange] = []
    var conflicted: [FileChange] = []

    static func make(unstaged: [FileChange], staged: [FileChange], conflicted: [FileChange], filter: String, options: ChangeListOptions = ChangeListOptions(), ignored: [FileChange] = []) -> ChangeLists {
        let query = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        func filtered(_ changes: [FileChange]) -> [FileChange] {
            guard !query.isEmpty else { return changes }
            return changes.filter { $0.path.localizedCaseInsensitiveContains(query) }
        }
        let shown = (unstaged + ignored).filter { !$0.isConflicted && options.admits($0) }
        return ChangeLists(filter: filter, options: options, ignored: ignored, unstaged: filtered(shown), staged: filtered(staged), conflicted: filtered(conflicted))
    }
}

struct PresentationChanges: OptionSet, Sendable {
    let rawValue: Int

    static let branches = PresentationChanges(rawValue: 1 << 0)
    static let changes = PresentationChanges(rawValue: 1 << 1)
    static let history = PresentationChanges(rawValue: 1 << 2)
    static let stashes = PresentationChanges(rawValue: 1 << 3)
    static let tags = PresentationChanges(rawValue: 1 << 4)
    static let state = PresentationChanges(rawValue: 1 << 5)
    static let remotes = PresentationChanges(rawValue: 1 << 6)
    static let worktrees = PresentationChanges(rawValue: 1 << 7)
    static let submodules = PresentationChanges(rawValue: 1 << 8)
    static let bisect = PresentationChanges(rawValue: 1 << 9)
    static let branchLists = PresentationChanges(rawValue: 1 << 10)
    static let changeLists = PresentationChanges(rawValue: 1 << 11)
    static let rows = PresentationChanges(rawValue: 1 << 12)
}

struct RepositoryPresentation: Sendable {
    var snapshot = RepositorySnapshot.empty
    var currentBranch: Branch?
    var localBranches: [Branch] = []
    var remoteBranches: [Branch] = []
    var stagedChanges: [FileChange] = []
    var unstagedChanges: [FileChange] = []
    var conflictedChanges: [FileChange] = []
    var detachedHead: Commit?
    var historyIndex: [String: Int] = [:]
    var rows: [HistoryRowModel] = []
    var graphLanes = 1
    var rowOptions = HistoryOptions.standard
    var branchLists = BranchLists()
    var changeLists = ChangeLists()

    static func present(
        _ snapshot: RepositorySnapshot,
        after previous: RepositoryPresentation,
        branchFilter: String,
        changesFilter: String,
        changeListOptions: ChangeListOptions = ChangeListOptions(),
        ignored: [FileChange] = [],
        options: HistoryOptions,
        sidebarOptions: SidebarOptions
    ) -> (RepositoryPresentation, PresentationChanges) {
        let old = previous.snapshot
        var next = previous
        var changed: PresentationChanges = []
        next.snapshot = snapshot

        if snapshot.branches != old.branches {
            changed.insert(.branches)
            next.currentBranch = snapshot.branches.first(where: \.isCurrent)
            next.localBranches = snapshot.branches.filter { !$0.isRemote }
            next.remoteBranches = snapshot.branches.filter(\.isRemote)
        }
        if snapshot.changes != old.changes {
            changed.insert(.changes)
            next.stagedChanges = snapshot.changes.filter(\.isStaged)
            next.unstagedChanges = snapshot.changes.filter(\.hasWorktreeChanges)
            next.conflictedChanges = snapshot.changes.filter(\.isConflicted)
        }
        let historyChanged = snapshot.history != old.history
        if historyChanged || snapshot.historyCursor != old.historyCursor { changed.insert(.history) }
        if historyChanged {
            next.historyIndex = Dictionary(snapshot.history.enumerated().map { ($1.commit.hash, $0) }) { first, _ in first }
        }
        if historyChanged || changed.contains(.branches) {
            next.detachedHead = next.currentBranch == nil ? snapshot.history.first { $0.commit.refNames.contains("HEAD") }?.commit : nil
        }
        if snapshot.stashes != old.stashes { changed.insert(.stashes) }
        if snapshot.tags != old.tags { changed.insert(.tags) }
        if snapshot.state != old.state { changed.insert(.state) }
        if snapshot.remotes != old.remotes { changed.insert(.remotes) }
        if snapshot.worktrees != old.worktrees { changed.insert(.worktrees) }
        if snapshot.submodules != old.submodules { changed.insert(.submodules) }
        if snapshot.bisect != old.bisect { changed.insert(.bisect) }

        if !changed.isDisjoint(with: [.branches, .remotes]) || branchFilter != previous.branchLists.filter || options.pinnedBranches != previous.branchLists.pinned || sidebarOptions.branchSortOrder != previous.branchLists.sortOrder || sidebarOptions.remoteBranchSortOrder != previous.branchLists.remoteSortOrder {
            let lists = BranchLists.make(local: next.localBranches, remote: next.remoteBranches, remotes: snapshot.remotes, filter: branchFilter, pinned: options.pinnedBranches, sortOrder: sidebarOptions.branchSortOrder, recent: sidebarOptions.recentlyUsedBranches, remoteSortOrder: sidebarOptions.remoteBranchSortOrder, remoteRecent: sidebarOptions.recentlyUsedRemoteBranches)
            if lists != previous.branchLists { changed.insert(.branchLists) }
            next.branchLists = lists
        }
        if changed.contains(.changes) || changesFilter != previous.changeLists.filter || changeListOptions != previous.changeLists.options || ignored != previous.changeLists.ignored {
            let lists = ChangeLists.make(unstaged: next.unstagedChanges, staged: next.stagedChanges, conflicted: next.conflictedChanges, filter: changesFilter, options: changeListOptions, ignored: ignored)
            if lists != previous.changeLists { changed.insert(.changeLists) }
            next.changeLists = lists
        }
        let labelOptions = HistoryOptions(hidesTags: options.hidesTags, hidesStashes: options.hidesStashes, hiddenBranches: options.hiddenBranches, filteredBranches: options.filteredBranches)
        if historyChanged || !changed.isDisjoint(with: [.branches, .bisect]) || labelOptions != previous.rowOptions {
            let context = HistoryRowModel.Context(remoteBranches: next.remoteBranches, options: labelOptions, bisect: snapshot.bisect)
            let reusable = changed.isDisjoint(with: [.branches, .bisect]) && labelOptions == previous.rowOptions
            let rows = reusable ? HistoryRowModel.make(snapshot.history, reusing: previous.rows, context: context) : HistoryRowModel.make(snapshot.history, context: context)
            if rows != previous.rows { changed.insert(.rows) }
            next.rows = rows
            next.graphLanes = snapshot.history.map(\.width).max() ?? 1
            next.rowOptions = labelOptions
        }
        return (next, changed)
    }

    func appending(_ page: HistoryPage, options: HistoryOptions) -> RepositoryPresentation {
        var next = self
        let offset = snapshot.history.count
        let history = snapshot.history + page.rows
        next.snapshot = RepositorySnapshot(
            branches: snapshot.branches,
            changes: snapshot.changes,
            history: history,
            stashes: snapshot.stashes,
            tags: snapshot.tags,
            state: snapshot.state,
            remotes: snapshot.remotes,
            worktrees: snapshot.worktrees,
            submodules: snapshot.submodules,
            bisect: snapshot.bisect,
            historyCursor: page.cursor
        )
        for (index, row) in page.rows.enumerated() where next.historyIndex[row.commit.hash] == nil {
            next.historyIndex[row.commit.hash] = offset + index
        }
        let context = HistoryRowModel.Context(remoteBranches: remoteBranches, options: options, bisect: snapshot.bisect)
        next.rows = rows + HistoryRowModel.make(page.rows, context: context)
        next.graphLanes = max(graphLanes, page.rows.map(\.width).max() ?? 1)
        return next
    }
}
