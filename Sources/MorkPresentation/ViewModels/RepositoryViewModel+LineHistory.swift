import MorkDomain
import Foundation

extension RepositoryViewModel {
    public func showLineHistory(_ request: LineHistoryRequest) {
        let inspector = FileInspector.lineHistory(request)
        open(inspector)
        inspection.lineHistory = .loading
        let load = dependencies.exploration.loadLineHistory
        let limit = Self.historyLimit
        explorationTasks.inspection = Task { [weak self] in
            let result: Loadable<[LineHistoryEntry]>
            do {
                result = .loaded(try await load.execute(request: request, limit: limit))
            } catch {
                result = .failed(error.localizedDescription)
            }
            guard !Task.isCancelled, let self, self.fileInspector == inspector else { return }
            self.inspection.lineHistory = result
            if case let .loaded(entries) = result, let first = entries.first {
                self.select(first)
            }
        }
    }

    public func select(_ entry: LineHistoryEntry) {
        inspection.selectedLineEntry = entry
        inspection.diff = .loaded(entry.diff)
    }

    func lineHistoryRequest(for line: DiffLine) -> LineHistoryRequest? {
        guard line.kind != .meta, line.kind != .hunk else { return nil }
        switch selection {
        case let .commitFile(commit, file):
            return Self.commitRequest(lines: [line], commit: commit, file: file)
        case let .file(change, _):
            let selected = selectedDiffLines(containing: line)
            return Self.workingCopyRequest(lines: selected.isEmpty ? [line] : selected, change: change)
        case .commit, nil:
            return nil
        }
    }

    func hunkLineHistoryRequest(for line: DiffLine) -> LineHistoryRequest? {
        guard line.kind != .meta, line.kind != .hunk, let lines = diffDocument?.lines else { return nil }
        let hunk = DiffLine.hunkLines(around: line.id, in: lines)
        switch selection {
        case let .commitFile(commit, file):
            return Self.commitRequest(lines: hunk, commit: commit, file: file)
        case let .file(change, _):
            return Self.workingCopyRequest(lines: hunk, change: change)
        case .commit, nil:
            return nil
        }
    }

    private func selectedDiffLines(containing line: DiffLine) -> [DiffLine] {
        guard let source = line.source, lineSelection.contains(source), let lines = diffDocument?.lines else { return [] }
        return lines.filter { $0.source.map(lineSelection.contains) ?? false }
    }

    static func commitRequest(lines: [DiffLine], commit: Commit, file: CommitFileChange) -> LineHistoryRequest? {
        let newNumbers = lines.compactMap(\.newNumber)
        if let low = newNumbers.min(), let high = newNumbers.max() {
            return LineHistoryRequest(path: file.path, start: low, end: high, revision: commit.hash)
        }
        let oldNumbers = lines.compactMap(\.oldNumber)
        guard !commit.parents.isEmpty, let low = oldNumbers.min(), let high = oldNumbers.max() else { return nil }
        return LineHistoryRequest(path: file.originalPath ?? file.path, start: low, end: high, revision: commit.hash + "^")
    }

    static func workingCopyRequest(lines: [DiffLine], change: FileChange) -> LineHistoryRequest? {
        let oldNumbers = lines.compactMap(\.oldNumber)
        guard !change.isUntracked, let low = oldNumbers.min(), let high = oldNumbers.max() else { return nil }
        return LineHistoryRequest(path: change.originalPath ?? change.path, start: low, end: high, revision: "HEAD")
    }
}
