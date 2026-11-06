import MorkDomain
import Foundation

struct StagingMove: Equatable {
    let change: FileChange
    let toStaged: Bool

    var placeholder: FileChange {
        if toStaged {
            let index: Character = change.isUntracked ? "A" : change.worktree == "D" ? "D" : "M"
            return FileChange(path: change.path, originalPath: change.originalPath, index: index, worktree: " ")
        }
        if change.index == "A" { return FileChange(path: change.path, index: "?", worktree: "?") }
        return FileChange(path: change.path, originalPath: change.originalPath, index: " ", worktree: change.index == "D" ? "D" : "M")
    }
}

extension RepositoryViewModel {
    public func toggleStagingKeepingPosition(_ changes: [FileChange], staged: Bool) async {
        await moveStaging(changes, toStaged: !staged, keepingPosition: true)
    }

    func moveStaging(_ changes: [FileChange], toStaged: Bool, keepingPosition: Bool = false) async {
        let movable = changes.filter { !$0.isConflicted }
        guard !movable.isEmpty else { return }
        let paths = movable.filter { !$0.isIgnored }.map(\.path).sorted()
        let ignored = movable.filter(\.isIgnored).map(\.path).sorted()
        await moveStaging(changes, toStaged: toStaged, keepingPosition: keepingPosition) { dependencies in
            if toStaged {
                if !paths.isEmpty { try await dependencies.stageFiles.execute(paths: paths) }
                if !ignored.isEmpty { try await dependencies.tools.stageIgnoredFiles.execute(paths: ignored) }
            } else {
                try await dependencies.unstageFiles.execute(paths: paths)
            }
        }
    }

    func moveStaging(_ changes: [FileChange], toStaged: Bool, keepingPosition: Bool = false, running command: (RepositoryDependencies) async throws -> Void) async {
        workingDiffs.clear()
        let moves = changes.filter { !$0.isConflicted }.map { StagingMove(change: $0, toStaged: toStaged) }
        let moving = Set(moves.map(\.change.path))
        let before = keepingPosition ? changeRows(staged: !toStaged) : []
        for move in moves {
            stagingMoves[move.change.path] = move
        }
        if !moves.isEmpty {
            refreshVisibleChanges(animated: true)
            if !keepingPosition || !selectRemaining(after: before, moving: moving, staged: !toStaged) {
                followSelection(to: toStaged, paths: moving)
            }
        }
        let succeeded = await perform(command)
        let unmoved = Set((toStaged ? unstagedChanges.filter { !$0.isConflicted } : stagedChanges).map(\.path))
        for move in moves where stagingMoves[move.change.path] == move && (!succeeded || unmoved.contains(move.change.path)) {
            stagingMoves[move.change.path] = nil
        }
        if !moves.isEmpty {
            refreshVisibleChanges(animated: !succeeded)
            if !succeeded { followSelection(to: !toStaged, paths: moving) }
        }
        settleStagingMoves()
    }

    private func selectRemaining(after before: [FileListRow<FileChange>], moving: Set<String>, staged: Bool) -> Bool {
        let start = before.firstIndex { row in
            if let file = row.file { return moving.contains(file.path) }
            guard !row.isExpanded, let folder = row.folderPath else { return false }
            return moving.contains { $0.hasPrefix(folder + "/") }
        }
        let rows = changeRows(staged: staged)
        guard let start, let last = rows.last else { return false }
        let remaining = Dictionary(rows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let after = before[start...].compactMap { remaining[$0.id] }
        let row = after.first { $0.file != nil } ?? after.first ?? last
        if let file = row.file {
            selection = .file(file, staged: staged)
        } else if let folder = row.folderPath {
            selectChangeFolder(folder, staged: staged)
        }
        return true
    }

    private static func gitLists(_ change: FileChange, after other: FileChange) -> Bool {
        if change.isUntracked != other.isUntracked { return change.isUntracked }
        return change.path > other.path
    }

    private static func arriving(_ moves: [StagingMove], in destination: [FileChange]) -> [FileChange] {
        guard !moves.isEmpty else { return [] }
        let real = Dictionary(destination.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
        return moves.map { real[$0.change.path] ?? $0.placeholder }
    }

    private static func merging(_ list: [FileChange], _ inserted: [FileChange]) -> [FileChange] {
        guard !inserted.isEmpty else { return list }
        let inserted = inserted.sorted { gitLists($1, after: $0) }
        var merged: [FileChange] = []
        merged.reserveCapacity(list.count + inserted.count)
        var next = inserted.startIndex
        for change in list {
            while next < inserted.endIndex, gitLists(change, after: inserted[next]) {
                merged.append(inserted[next])
                next += 1
            }
            merged.append(change)
        }
        merged.append(contentsOf: inserted[next...])
        return merged
    }

    private func followSelection(to staged: Bool, paths: Set<String>) {
        guard case let .file(selected, wasStaged) = selection, paths.contains(selected.path), wasStaged != staged else { return }
        let list = staged ? visibleStagedChanges : visibleUnstagedChanges
        if let moved = list.first(where: { $0.path == selected.path }) {
            selection = .file(moved, staged: staged)
        }
    }

    func settleStagingMoves() {
        let lists = presentation.changeLists
        guard !stagingMoves.isEmpty else { return }
        let staged = Set(stagedChanges.map(\.path))
        let unstaged = Set(unstagedChanges.map(\.path))
        let unstagedResolved = Set(unstagedChanges.filter { !$0.isConflicted }.map(\.path))
        for (path, move) in stagingMoves {
            let arrived = move.toStaged ? staged.contains(path) : unstaged.contains(path)
            let left = move.toStaged ? !unstagedResolved.contains(path) : !staged.contains(path)
            if arrived, left { stagingMoves[path] = nil }
        }
        if stagingMoves.isEmpty, visibleUnstagedChanges != lists.unstaged || visibleStagedChanges != lists.staged {
            refreshVisibleChanges(animated: false)
        }
    }

    func refreshVisibleChanges(animated: Bool) {
        let lists = presentation.changeLists
        var unstaged = lists.unstaged
        var staged = lists.staged
        if !stagingMoves.isEmpty {
            let query = lists.filter.trimmingCharacters(in: .whitespacesAndNewlines)
            let shown = stagingMoves.filter { query.isEmpty || $0.key.localizedCaseInsensitiveContains(query) }
            let toStaged = Self.arriving(shown.values.filter(\.toStaged), in: stagedChanges)
            let toUnstaged = Self.arriving(shown.values.filter { !$0.toStaged }, in: unstagedChanges).filter(lists.options.admits)
            unstaged = Self.merging(unstaged.filter { stagingMoves[$0.path] == nil }, toUnstaged)
            staged = Self.merging(staged.filter { stagingMoves[$0.path] == nil }, toStaged)
        }
        let changed = unstaged != visibleUnstagedChanges || staged != visibleStagedChanges
        if animated, changed { stagingTick &+= 1 }
        if unstaged != visibleUnstagedChanges { visibleUnstagedChanges = unstaged }
        if staged != visibleStagedChanges { visibleStagedChanges = staged }
    }
}
