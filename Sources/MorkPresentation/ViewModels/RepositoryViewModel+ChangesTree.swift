import MorkDomain
import Foundation

extension RepositoryViewModel {
    public func toggleChangesFolder(_ path: String, staged: Bool) {
        if staged {
            collapsedStagedFolders.formSymmetricDifference([path])
        } else {
            collapsedUnstagedFolders.formSymmetricDifference([path])
        }
    }

    public func selectChangeRows(_ rows: [FileListRow<FileChange>], staged: Bool) {
        setSelectedChangeRows(Set(rows.map(\.id)), staged: staged)
        if !rows.isEmpty, rows.allSatisfy({ $0.file == nil }) { selection = nil }
    }

    public func toggleFolderStaging(_ path: String, staged: Bool) async {
        let files = FileList.files(changeList(staged: staged), matching: [FileList.folderID(path)], path: \.path)
        await toggleStaging(Set(files.map { .file($0, staged: staged) }))
    }

    func selectedChanges(staged: Bool, clicked: String? = nil) -> [FileChange] {
        let ids = staged ? selectedStagedRowIDs : selectedUnstagedRowIDs
        let targets = clicked.map { ids.contains($0) ? ids : [$0] } ?? ids
        return FileList.files(changeList(staged: staged), matching: targets, path: \.path)
    }

    func changeRows(staged: Bool) -> [FileListRow<FileChange>] {
        staged ? stagedChangeRows : unstagedChangeRows
    }

    func selectChangeFolder(_ path: String, staged: Bool) {
        selection = nil
        setSelectedChangeRows([FileList.folderID(path)], staged: staged)
    }

    func isHiddenInChanges(_ path: String, staged: Bool) -> Bool {
        changesListMode == .tree && (staged ? collapsedStagedFolders : collapsedUnstagedFolders).contains { path.hasPrefix($0 + "/") }
    }

    func rebuildChangeRows(staged: Bool) {
        let rows = FileList.rows(
            changeList(staged: staged),
            mode: changesListMode,
            collapsed: staged ? collapsedStagedFolders : collapsedUnstagedFolders,
            path: \.path
        )
        if staged { stagedChangeRows = rows } else { unstagedChangeRows = rows }
        let selected = staged ? selectedStagedRowIDs : selectedUnstagedRowIDs
        let kept = FileList.reconcile(selected, to: rows)
        if kept != selected {
            if staged { selectedStagedRowIDs = kept } else { selectedUnstagedRowIDs = kept }
        }
        if case let .file(change, isStaged) = selection, isStaged == staged, isHiddenInChanges(change.path, staged: staged) {
            selection = nil
        }
    }

    func syncSelectedChangeRows() {
        switch selection {
        case nil:
            break
        case let .file(change, isStaged):
            let ids = isStaged ? selectedStagedRowIDs : selectedUnstagedRowIDs
            setSelectedChangeRows(ids.contains(change.path) ? ids : [change.path], staged: isStaged)
        case .commit, .commitFile:
            setSelectedChangeRows([], staged: false)
            setSelectedChangeRows([], staged: true)
        }
    }

    private func setSelectedChangeRows(_ ids: Set<String>, staged: Bool) {
        if staged {
            if selectedStagedRowIDs != ids { selectedStagedRowIDs = ids }
            if !ids.isEmpty, !selectedUnstagedRowIDs.isEmpty { selectedUnstagedRowIDs = [] }
        } else {
            if selectedUnstagedRowIDs != ids { selectedUnstagedRowIDs = ids }
            if !ids.isEmpty, !selectedStagedRowIDs.isEmpty { selectedStagedRowIDs = [] }
        }
    }

    private func changeList(staged: Bool) -> [FileChange] {
        staged ? visibleStagedChanges : visibleUnstagedChanges
    }
}
