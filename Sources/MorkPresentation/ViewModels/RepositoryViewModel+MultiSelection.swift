import MorkDomain
import Foundation

public enum MultiCommitDiffTarget: Equatable, Sendable {
    case checking
    case range(CommitRange)
    case multipleRevisions
}

public enum MultiCommitAction: Sendable {
    case cherryPick
    case revert
    case savePatch
}

extension RepositoryViewModel {
    static let rangeCheckCacheLimit = 256
    static let patchFolderPlaceholder = "<folder>"

    public var isMultiCommitSelection: Bool { multiSelectionRows.count > 1 }

    public var selectedCommits: [Commit] {
        if isMultiCommitSelection { return multiSelectionRows.map(\.commit) }
        return selectedCommit.map { [$0] } ?? []
    }

    public var selectedCommitRange: CommitRange? {
        guard isMultiCommitSelection, case let .range(range) = multiCommitDiffTarget else { return nil }
        return range
    }

    public var selectedCommitSHAs: String { selectedCommits.map(\.hash).joined(separator: "\n") }
    public var selectedCommitSubjects: String { selectedCommits.map(\.subject).joined(separator: "\n") }

    public func clickCommit(_ hash: String?, extending: Bool = false, toggling: Bool = false) {
        if extending, let hash, let run = historyRun(from: selectionAnchor ?? selectedCommit?.hash ?? hash, to: hash) {
            applyCommitSelection(run.rows, isConsecutive: true, hashes: run.hashes, focus: hash)
        } else if toggling, let target = hash ?? selectedCommit?.hash {
            var hashes = selectedCommitHashes
            let removed = hashes.remove(target) != nil
            if !removed { hashes.insert(target) }
            selectionAnchor = target
            selectCommits(hashes, focus: removed ? nil : target)
        } else {
            selectionAnchor = hash
            selectCommits(hash.map { [$0] } ?? [], focus: hash)
        }
    }

    public func selectFromHistoryList(_ hash: String?, extending: Bool) {
        guard hash != selectedCommit?.hash else { return }
        clickCommit(hash, extending: extending)
    }

    public func selectAllCommits() {
        let rows = visibleHistoryRows
        guard rows.count > 1 else { return }
        applyCommitSelection(rows, isConsecutive: true, hashes: Set(rows.map(\.id)), focus: selectedCommit?.hash)
    }

    public func selectCommits(_ hashes: Set<String>, focus: String? = nil) {
        guard hashes != selectedCommitHashes || (focus != nil && focus != selectedCommit?.hash) else { return }
        let ordered = orderedSelection(hashes)
        applyCommitSelection(ordered.rows, isConsecutive: ordered.isConsecutive, hashes: hashes, focus: focus)
    }

    public func multiCommitArguments(for action: MultiCommitAction, abbreviated: Bool = true) -> [String]? {
        let commits = selectedCommits
        guard commits.count > 1 else { return nil }
        switch action {
        case .cherryPick: return CherryPickOptions.standard.arguments(picking: commits, abbreviated: abbreviated)
        case .revert: return RevertOptions.standard.arguments(reverting: commits, abbreviated: abbreviated)
        case .savePatch: return selectedCommitRange?.patchArguments(folder: Self.patchFolderPlaceholder, abbreviated: abbreviated)
        }
    }

    public func cherryPickSelectedCommits() async {
        let commits = selectedCommits
        guard commits.count > 1 else { return }
        await perform { try await $0.range.cherryPickCommits.execute(newestFirst: commits, options: .standard) }
    }

    public func revertSelectedCommits() async {
        let commits = selectedCommits
        guard commits.count > 1 else { return }
        await perform { try await $0.range.revertCommits.execute(newestFirst: commits, options: .standard) }
    }

    public func saveSelectedRangeAsPatch() async {
        guard let range = selectedCommitRange,
              let folder = await dependencies.range.folderPanel.chooseFolder(prompt: "Save Patches") else { return }
        var written: [String] = []
        if await perform({ written = try await $0.range.savePatch.execute(range: range, folder: folder) }) {
            let command = (["git"] + range.patchArguments(folder: folder.path, abbreviated: true)).joined(separator: " ")
            notice = Notice(
                title: "Patches Saved",
                message: "\(command) wrote \(written.count) patch \(written.count == 1 ? "file" : "files") to \(folder.path). Apply them in another repository with git am."
            )
        }
    }

    func visibleHistoryCommit(_ hash: String) -> Commit? {
        let rows = visibleHistoryRows
        if searchRows == nil, let index = presentation.historyIndex[hash], rows.indices.contains(index) { return rows[index].commit }
        return rows.first { $0.id == hash }?.commit
    }

    func syncCommitSelection(from oldValue: Selection?) {
        let commit = selectedCommit
        guard Self.commit(of: oldValue)?.hash != commit?.hash else { return }
        if isMultiCommitSelection { endMultiSelection() }
        selectionAnchor = commit?.hash
        let hashes: Set<String> = commit.map { [$0.hash] } ?? []
        if hashes != selectedCommitHashes { selectedCommitHashes = hashes }
    }

    func reconcileMultiSelection() {
        let ordered = orderedSelection(selectedCommitHashes)
        applyCommitSelection(ordered.rows, isConsecutive: ordered.isConsecutive, hashes: selectedCommitHashes, focus: selectedCommit?.hash)
    }

    func showRangeChangesIfVisible() {
        guard commitDetailsTab == .changes, let range = selectedCommitRange else { return }
        rangeChanges.show(range)
    }

    public func waitForRangeCheck() async {
        await rangeCheckTask?.value
    }

    private func applyCommitSelection(_ rows: [HistoryRowModel], isConsecutive: Bool, hashes: Set<String>, focus: String?) {
        guard rows.count > 1 else {
            selectSingleCommit(rows.first?.commit)
            return
        }
        let previous = selectedCommitHashes
        let focused = focus.flatMap { hash in rows.first { $0.id == hash }?.commit }
            ?? selectedCommit.flatMap { hashes.contains($0.hash) ? $0 : nil }
            ?? rows.first { !previous.contains($0.id) }?.commit
            ?? rows[0].commit
        isSelectingCommits = true
        selectedCommitHashes = rows.count == hashes.count ? hashes : Set(rows.map(\.id))
        if rows != multiSelectionRows { multiSelectionRows = rows }
        isMultiSelectionConsecutive = isConsecutive
        if selectedCommit?.hash != focused.hash { selection = .commit(focused) }
        isSelectingCommits = false
        updateMultiCommitDiffTarget()
    }

    private func historyRun(from anchor: String, to hash: String) -> (rows: [HistoryRowModel], hashes: Set<String>)? {
        guard let start = visiblePosition(of: anchor), let end = visiblePosition(of: hash) else { return nil }
        let rows = Array(visibleHistoryRows[min(start, end)...max(start, end)])
        return (rows, Set(rows.map(\.id)))
    }

    private func visiblePosition(of hash: String) -> Int? {
        let rows = visibleHistoryRows
        if searchRows == nil, let index = presentation.historyIndex[hash], rows.indices.contains(index), rows[index].id == hash { return index }
        return rows.firstIndex { $0.id == hash }
    }

    private func selectSingleCommit(_ commit: Commit?) {
        let wasMulti = isMultiCommitSelection
        guard let commit, selectedCommit?.hash == commit.hash else {
            selection = commit.map { .commit($0) }
            if selection == nil, !selectedCommitHashes.isEmpty { selectedCommitHashes = [] }
            return
        }
        if wasMulti { endMultiSelection() }
        if selectedCommitHashes != [commit.hash] { selectedCommitHashes = [commit.hash] }
        guard wasMulti else { return }
        reloadCommitInfo()
        reloadDetail()
        autoSelectChangesFile()
        rebuildCommitTabRows()
        rebuildCommitFileRows()
        if commitDetailsTab == .fileTree { showFileTree() }
    }

    private func endMultiSelection() {
        rangeCheckTask?.cancel()
        rangeCheckTask = nil
        multiSelectionRows = []
        isMultiSelectionConsecutive = false
        if multiCommitDiffTarget != .checking { multiCommitDiffTarget = .checking }
    }

    private func orderedSelection(_ hashes: Set<String>) -> (rows: [HistoryRowModel], isConsecutive: Bool) {
        let rows = visibleHistoryRows
        var positions: [Int] = []
        if searchRows == nil, hashes.count * 8 < rows.count {
            positions.reserveCapacity(hashes.count)
            for hash in hashes {
                if let index = presentation.historyIndex[hash], rows.indices.contains(index), rows[index].id == hash { positions.append(index) }
            }
            positions.sort()
        } else {
            for (index, row) in rows.enumerated() where hashes.contains(row.id) { positions.append(index) }
        }
        guard let first = positions.first, let last = positions.last else { return ([], false) }
        return (positions.map { rows[$0] }, last - first == positions.count - 1)
    }

    private func updateMultiCommitDiffTarget() {
        rangeCheckTask?.cancel()
        rangeCheckTask = nil
        guard isMultiSelectionConsecutive, let newest = multiSelectionRows.first?.commit, let oldest = multiSelectionRows.last?.commit else {
            setMultiCommitDiffTarget(.multipleRevisions)
            return
        }
        let key = "\(oldest.hash)..\(newest.hash)"
        if let checked = rangeChecks[key] {
            setMultiCommitDiffTarget(checked.map(MultiCommitDiffTarget.range) ?? .multipleRevisions)
            return
        }
        setMultiCommitDiffTarget(.checking)
        let check = dependencies.range.checkRange
        rangeCheckTask = Task { [weak self] in
            let checked: CommitRange?
            do {
                checked = try await check.execute(oldest: oldest, newest: newest)
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.setMultiCommitDiffTarget(.multipleRevisions)
                return
            }
            guard !Task.isCancelled, let self else { return }
            if self.rangeChecks.count >= Self.rangeCheckCacheLimit { self.rangeChecks = [:] }
            self.rangeChecks[key] = .some(checked)
            self.setMultiCommitDiffTarget(checked.map(MultiCommitDiffTarget.range) ?? .multipleRevisions)
        }
    }

    private func setMultiCommitDiffTarget(_ target: MultiCommitDiffTarget) {
        if multiCommitDiffTarget != target { multiCommitDiffTarget = target }
        showRangeChangesIfVisible()
    }
}
