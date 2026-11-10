import MorkDomain
import Foundation
import Observation

public struct MeldMarker: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let start = MeldMarker(rawValue: 1)
    public static let through = MeldMarker(rawValue: 2)
    public static let end = MeldMarker(rawValue: 4)
}

public struct RewordMessage: Equatable, Sendable {
    public let shortHash: String
    public let message: String

    public init(shortHash: String, message: String) {
        self.shortHash = shortHash
        self.message = message
    }
}

public struct RebaseMessageDraft: Identifiable, Equatable, Sendable {
    public let stepID: RebaseStep.ID
    public let shortHash: String
    public let previousAction: RebaseAction
    public var subject: String
    public var description: String

    init(step: RebaseStep) {
        let lines = step.message.split(maxSplits: 1, omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        stepID = step.id
        shortHash = step.commit.shortHash
        previousAction = step.action
        subject = lines.first.map(String.init) ?? ""
        description = lines.count > 1 ? String(lines[1]).trimmingCharacters(in: .whitespacesAndNewlines) : ""
    }

    public var id: RebaseStep.ID { stepID }
    public var canSave: Bool { !trimmedSubject.isEmpty }

    var message: String {
        let body = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return body.isEmpty ? trimmedSubject : "\(trimmedSubject)\n\n\(body)"
    }

    private var trimmedSubject: String { subject.trimmingCharacters(in: .whitespacesAndNewlines) }
}

struct RebaseCommitChanges {
    let summary: @MainActor (Commit) async -> Result<CommitSummary, Error>
    let diffs: @MainActor ([CommitFileChange], Commit) async -> [String: InlineDiffState]
    let fullDiff: @MainActor (CommitFileChange, Commit) async -> InlineDiffState
    let settings: @MainActor () -> DiffSettings
    let changeSettings: @MainActor ((inout DiffSettings) -> Void) -> Void
}

public enum RebaseDetailsTab: String, CaseIterable, Sendable {
    case commit
    case changes
    case todo

    public var title: String {
        switch self {
        case .commit: "Commit"
        case .changes: "Changes"
        case .todo: "git-rebase-todo"
        }
    }
}

enum RebaseCommitFiles: Equatable {
    case loading
    case loaded([CommitFileChange])
    case failed(String)
}

@MainActor
@Observable
public final class InteractiveRebaseViewModel: Identifiable {
    public typealias Run = @MainActor ([RebaseStep], InteractiveRebaseOptions) async -> Void

    public let id = UUID()
    public let base: RebaseBase
    public let branchName: String
    public let skippedMerges: [Commit]
    public let hasUncommittedChanges: Bool
    public private(set) var steps: [RebaseStep] {
        didSet { meldMarkers = Self.meldMarkers(for: steps.reversed()) }
    }
    public private(set) var meldMarkers: [RebaseStep.ID: MeldMarker] = [:]
    public private(set) var isRunning = false
    public private(set) var messageDraft: RebaseMessageDraft?
    public var selectedStepID: RebaseStep.ID? {
        didSet { if selectedStepID != oldValue { showSelectedCommit() } }
    }
    public var updatesDependentBranches = false
    public var createsBackup = false
    private(set) var commitFiles: RebaseCommitFiles?
    private(set) var commitTabRows: [CommitTabRow] = []
    public private(set) var areAllInlineDiffsExpanded = false
    public var detailsTab = RebaseDetailsTab.commit {
        didSet { if detailsTab != oldValue { loadSelectedChangesDiff() } }
    }
    public var changesFilter = "" {
        didSet { if changesFilter != oldValue { rebuildCommitTabRows() } }
    }
    public var changesFileListMode = FileListMode.flat {
        didSet { if changesFileListMode != oldValue { rebuildCommitTabRows() } }
    }
    public var selectedChangesPath: String? {
        didSet { if selectedChangesPath != oldValue { loadSelectedChangesDiff() } }
    }
    public private(set) var changesRows: [CommitFileListRow] = []
    private(set) var changesDiff: InlineDiffState?

    @ObservationIgnored private let run: Run
    @ObservationIgnored private let changes: RebaseCommitChanges?
    @ObservationIgnored private var filesByCommit: [String: RebaseCommitFiles] = [:]
    @ObservationIgnored private var diffsByCommit: [String: [String: InlineDiffState]] = [:]
    @ObservationIgnored private var expanded: Set<String> = []
    @ObservationIgnored private var tasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var changesRowsSource: CommitFileRowsSource?

    public convenience init(base: RebaseBase, branchName: String, steps: [RebaseStep], skippedMerges: [Commit] = [], hasUncommittedChanges: Bool, run: @escaping Run) {
        self.init(base: base, branchName: branchName, steps: steps, skippedMerges: skippedMerges, hasUncommittedChanges: hasUncommittedChanges, changes: nil, run: run)
    }

    init(base: RebaseBase, branchName: String, steps: [RebaseStep], skippedMerges: [Commit], hasUncommittedChanges: Bool, changes: RebaseCommitChanges?, run: @escaping Run) {
        self.base = base
        self.branchName = branchName
        self.steps = steps
        self.skippedMerges = skippedMerges
        self.hasUncommittedChanges = hasUncommittedChanges
        self.changes = changes
        self.run = run
        selectedStepID = steps.last?.id
        meldMarkers = Self.meldMarkers(for: steps.reversed())
        showSelectedCommit()
    }

    public var displayedSteps: [RebaseStep] { steps.reversed() }
    public var selectedStep: RebaseStep? { selectedStepID.flatMap(index(of:)).map { steps[$0] } }

    public var skippedMergesNotice: String? {
        guard !skippedMerges.isEmpty else { return nil }
        let count = skippedMerges.count == 1 ? "1 merge commit is" : "\(skippedMerges.count) merge commits are"
        return "\(count) left out. git rebase -i replays only regular commits, one after another, so the history ends up on one line. Use git rebase -i --rebase-merges in the console to keep the merges."
    }

    public var startTitle: String { hasUncommittedChanges ? "Stash and Rebase" : "Rebase" }

    public var command: String {
        (["git"] + RebaseCommand.interactive(onto: base, autostash: hasUncommittedChanges, updateRefs: updatesDependentBranches)).map(ShellWords.quote).joined(separator: " ")
    }

    public var preview: String { (try? RebaseTodoBuilder.build(steps))?.text ?? "" }
    public var canStart: Bool { !isRunning && validationMessage == nil }

    public var validationMessage: String? {
        do {
            _ = try RebaseTodoBuilder.build(steps)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    public var rewordMessages: [RewordMessage] {
        steps.filter { $0.action == .reword }.map { RewordMessage(shortHash: $0.commit.shortHash, message: $0.message) }
    }

    public func setAction(_ action: RebaseAction, for id: RebaseStep.ID) {
        guard let index = index(of: id) else { return }
        if action == .reword {
            messageDraft = RebaseMessageDraft(step: steps[index])
        }
        steps[index].action = action
    }

    public func saveMessage(_ draft: RebaseMessageDraft) {
        guard draft.canSave, let index = index(of: draft.stepID) else { return }
        if draft != messageDraft {
            steps[index].message = draft.message
        }
        messageDraft = nil
    }

    public func cancelMessageEdit() {
        guard let draft = messageDraft, let index = index(of: draft.stepID) else { return }
        steps[index].action = draft.previousAction
        messageDraft = nil
    }

    public func moveDisplayed(fromOffsets source: IndexSet, toOffset destination: Int) {
        var displayed = displayedSteps
        displayed.move(fromOffsets: source, toOffset: destination)
        steps = displayed.reversed()
    }

    public enum Direction: Sendable {
        case up
        case down
    }

    public func canMoveSelected(_ direction: Direction) -> Bool {
        guard let target = displayedTarget(direction) else { return false }
        return displayedSteps.indices.contains(target)
    }

    public func moveSelected(_ direction: Direction) {
        guard let id = selectedStepID, let target = displayedTarget(direction), displayedSteps.indices.contains(target),
              let current = displayedSteps.firstIndex(where: { $0.id == id }) else { return }
        var displayed = displayedSteps
        displayed.swapAt(current, target)
        steps = displayed.reversed()
    }

    @discardableResult
    public func applyShortcut(_ key: Character) -> Bool {
        guard messageDraft == nil, let id = selectedStepID, let action = RebaseAction(abbreviation: key) else { return false }
        setAction(action, for: id)
        return true
    }

    private static func meldMarkers(for displayed: [RebaseStep]) -> [RebaseStep.ID: MeldMarker] {
        var markers: [RebaseStep.ID: MeldMarker] = [:]
        for (index, step) in displayed.enumerated() where step.action.meldsIntoPrevious {
            guard let target = displayed.indices.dropFirst(index + 1).first(where: { displayed[$0].action != .drop }) else { continue }
            markers[step.id, default: []].insert(.start)
            for crossed in (index + 1)..<target {
                markers[displayed[crossed].id, default: []].insert(.through)
            }
            markers[displayed[target].id, default: []].insert(.end)
        }
        return markers
    }

    private func displayedTarget(_ direction: Direction) -> Int? {
        guard let id = selectedStepID, let current = displayedSteps.firstIndex(where: { $0.id == id }) else { return nil }
        return direction == .up ? current - 1 : current + 1
    }

    public func editMessage(for id: RebaseStep.ID) {
        setAction(.reword, for: id)
    }

    public func start() async {
        guard canStart else { return }
        isRunning = true
        let backup = createsBackup ? RebaseBackup.branchName(for: branchName, at: Date()) : nil
        await run(steps, InteractiveRebaseOptions(autostash: hasUncommittedChanges, updateRefs: updatesDependentBranches, backupBranch: backup))
        isRunning = false
    }

    public func toggleInlineDiff(_ file: CommitFileChange) {
        guard let commit = selectedStep?.commit, case let .loaded(files) = commitFiles, files.contains(file) else { return }
        if expanded.remove(file.path) == nil {
            expanded.insert(file.path)
            loadDiffs([file], in: commit)
        }
        rebuildCommitTabRows()
    }

    public func expandAllInlineDiffs() {
        guard let commit = selectedStep?.commit, case let .loaded(files) = commitFiles, !files.isEmpty else { return }
        expanded = Set(files.map(\.path))
        loadDiffs(files, in: commit)
        rebuildCommitTabRows()
    }

    public func collapseAllInlineDiffs() {
        guard !expanded.isEmpty else { return }
        expanded = []
        rebuildCommitTabRows()
    }

    public var selectedChangesFile: CommitFileChange? {
        guard let path = selectedChangesPath, case let .loaded(files) = commitFiles else { return nil }
        return files.first { $0.path == path }
    }

    public var diffSettings: DiffSettings { changes?.settings() ?? DiffSettings() }

    public func changeDiffSettings(_ change: (inout DiffSettings) -> Void) {
        guard let changes else { return }
        let previous = changes.settings().options
        changes.changeSettings(change)
        guard changes.settings().options != previous, let commit = selectedStep?.commit else { return }
        diffsByCommit = [:]
        if case let .loaded(files) = commitFiles { loadDiffs(files.filter { expanded.contains($0.path) }, in: commit) }
        loadSelectedChangesDiff()
    }

    public func showLargeChangesDiff() {
        guard let changes, let commit = selectedStep?.commit, let file = selectedChangesFile,
              case let .loaded(document)? = diffsByCommit[commit.hash]?[file.path], document.isCollapsed else { return }
        diffsByCommit[commit.hash, default: [:]][file.path] = .loading
        rebuildCommitTabRows()
        track { [weak self] in
            let state = await changes.fullDiff(file, commit)
            guard let self, self.diffsByCommit[commit.hash] != nil else { return }
            self.diffsByCommit[commit.hash, default: [:]][file.path] = state
            self.rebuildCommitTabRows()
        }
    }

    public func waitForCommitChanges() async {
        while let task = tasks.values.first {
            await task.value
        }
    }

    private func showSelectedCommit() {
        expanded = []
        let selectedHash = selectedStep?.commit.hash
        diffsByCommit = diffsByCommit.filter { $0.key == selectedHash }
        if let changes, let commit = selectedStep?.commit, filesByCommit[commit.hash] == nil {
            filesByCommit[commit.hash] = .loading
            track { [weak self] in
                let result = await changes.summary(commit)
                guard let self else { return }
                switch result {
                case let .success(summary): self.filesByCommit[commit.hash] = .loaded(summary.files)
                case let .failure(error): self.filesByCommit[commit.hash] = .failed(error.localizedDescription)
                }
                self.rebuildCommitTabRows()
                self.loadSelectedChangesDiff()
            }
        }
        rebuildCommitTabRows()
        loadSelectedChangesDiff()
    }

    private func loadSelectedChangesDiff() {
        if detailsTab == .changes, let commit = selectedStep?.commit, let file = selectedChangesFile {
            loadDiffs([file], in: commit)
        }
        rebuildCommitTabRows()
    }

    private func loadDiffs(_ files: [CommitFileChange], in commit: Commit) {
        guard let changes else { return }
        let known = diffsByCommit[commit.hash] ?? [:]
        let missing = files.filter { file in
            switch known[file.path] {
            case .loaded, .loading: false
            case .failed, nil: true
            }
        }
        guard !missing.isEmpty else { return }
        for file in missing { diffsByCommit[commit.hash, default: [:]][file.path] = .loading }
        track { [weak self] in
            let states = await changes.diffs(missing, commit)
            guard let self, self.diffsByCommit[commit.hash] != nil else { return }
            self.diffsByCommit[commit.hash, default: [:]].merge(states) { _, new in new }
            self.rebuildCommitTabRows()
        }
    }

    private func rebuildCommitTabRows() {
        let commit = selectedStep?.commit
        let state = commit.flatMap { filesByCommit[$0.hash] }
        if state != commitFiles { commitFiles = state }
        let files: [CommitFileChange] = if case let .loaded(files) = state { files } else { [] }
        let diffs = commit.flatMap { diffsByCommit[$0.hash] } ?? [:]
        let rows = files.map { CommitTabRow(file: $0, isExpanded: expanded.contains($0.path), state: diffs[$0.path]) }
        if rows != commitTabRows { commitTabRows = rows }
        let allExpanded = !files.isEmpty && files.allSatisfy { expanded.contains($0.path) }
        if allExpanded != areAllInlineDiffsExpanded { areAllInlineDiffsExpanded = allExpanded }
        let source = CommitFileRowsSource(files: files, mode: changesFileListMode, filter: changesFilter)
        if source != changesRowsSource {
            changesRowsSource = source
            let changed = CommitFileList.rows(files, mode: changesFileListMode, filter: changesFilter)
            if changed != changesRows { changesRows = changed }
        }
        if let first = files.first, !files.contains(where: { $0.path == selectedChangesPath }) {
            selectedChangesPath = first.path
            return
        }
        let shown = selectedChangesPath.flatMap { diffs[$0] }
        if shown != changesDiff { changesDiff = shown }
    }

    private func track(_ work: @escaping @MainActor () async -> Void) {
        let id = UUID()
        tasks[id] = Task { [weak self] in
            await work()
            self?.tasks[id] = nil
        }
    }

    private func index(of id: RebaseStep.ID) -> Int? {
        steps.firstIndex { $0.id == id }
    }
}
