import MorkDomain
import Foundation

public enum Loadable<Value: Equatable & Sendable>: Equatable, Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(String)
}

public enum FileInspector: Identifiable, Hashable, Sendable {
    case history(path: String)
    case blame(path: String, commit: Commit?)
    case lineHistory(LineHistoryRequest)

    public var id: String {
        switch self {
        case let .history(path): "history:\(path)"
        case let .blame(path, commit): "blame:\(commit?.hash ?? "worktree"):\(path)"
        case let .lineHistory(request): "lines:\(request.revision):\(request.range):\(request.path)"
        }
    }

    public var path: String {
        switch self {
        case let .history(path), let .blame(path, _): path
        case let .lineHistory(request): request.path
        }
    }
}

public struct FileInspection: Equatable, Sendable {
    public var history: Loadable<[FileHistoryEntry]> = .idle
    public var selectedEntry: FileHistoryEntry?
    public var diff: RepositoryViewModel.Detail = .empty
    public var blame: Loadable<[BlameBlock]> = .idle
    public var lineHistory: Loadable<[LineHistoryEntry]> = .idle
    public var selectedLineEntry: LineHistoryEntry?
    public internal(set) var blameRows: [BlameRow] = []
    public internal(set) var blameColumns = 0

    public init() {}
}

public struct BlameRow: Identifiable, Equatable, Sendable {
    public enum Gutter: Equatable, Sendable {
        case commit
        case summary
        case none
    }

    public let line: BlameLine
    public let block: Int
    public let commit: BlameCommit
    public let gutter: Gutter
    public let isShaded: Bool

    public var id: Int { line.number }

    public static func rows(_ blocks: [BlameBlock]) -> (rows: [BlameRow], columns: Int) {
        var rows: [BlameRow] = []
        var columns = 0
        for block in blocks {
            for (offset, line) in block.lines.enumerated() {
                let gutter: Gutter = offset == 0 ? .commit : (offset == 1 ? .summary : .none)
                rows.append(BlameRow(line: line, block: block.index, commit: block.commit, gutter: gutter, isShaded: block.isShaded))
                columns = max(columns, line.content.count)
            }
        }
        return (rows, columns)
    }
}

extension RepositoryViewModel {
    public func showFileHistory(path: String) {
        let inspector = FileInspector.history(path: path)
        open(inspector)
        inspection.history = .loading
        let loadFileHistory = dependencies.exploration.loadFileHistory
        let limit = Self.historyLimit
        explorationTasks.inspection = Task { [weak self] in
            let result: Loadable<[FileHistoryEntry]>
            do {
                result = .loaded(try await loadFileHistory.execute(path: path, limit: limit))
            } catch {
                result = .failed(error.localizedDescription)
            }
            guard !Task.isCancelled, let self, self.fileInspector == inspector else { return }
            self.inspection.history = result
            if case let .loaded(entries) = result, let first = entries.first {
                self.select(first)
            }
        }
    }

    public func showBlame(path: String, at commit: Commit?) {
        let inspector = FileInspector.blame(path: path, commit: commit)
        open(inspector)
        inspection.blame = .loading
        let blameFile = dependencies.exploration.blameFile
        explorationTasks.inspection = Task { [weak self] in
            let result: Loadable<[BlameBlock]>
            var flattened: (rows: [BlameRow], columns: Int) = ([], 0)
            do {
                let blocks = try await blameFile.execute(path: path, commit: commit)
                flattened = await Task.detached(priority: .userInitiated) { BlameRow.rows(blocks) }.value
                result = .loaded(blocks)
            } catch {
                result = .failed(error.localizedDescription)
            }
            guard !Task.isCancelled, let self, self.fileInspector == inspector else { return }
            self.inspection.blameRows = flattened.rows
            self.inspection.blameColumns = flattened.columns
            self.inspection.blame = result
        }
    }

    public func select(_ entry: FileHistoryEntry) {
        explorationTasks.fileDiff?.cancel()
        inspection.selectedEntry = entry
        if case .loaded = inspection.diff {} else { inspection.diff = .loading }
        let loadCommitFileDiff = dependencies.loadCommitFileDiff
        explorationTasks.fileDiff = Task { [weak self] in
            let result: Detail
            do {
                result = .loaded(try await loadCommitFileDiff.execute(commit: entry.commit, file: entry.file))
            } catch {
                result = .failed(error.localizedDescription)
            }
            guard !Task.isCancelled, let self, self.inspection.selectedEntry == entry else { return }
            self.inspection.diff = result
        }
    }

    public func reveal(_ commit: BlameCommit) async {
        guard !commit.isUncommitted else { return }
        closeFileInspector()
        pane = .history
        let target: Commit
        if let loaded = historyRows.first(where: { $0.commit.hash == commit.hash })?.commit {
            target = loaded
        } else {
            do {
                let loadCommit = dependencies.exploration.loadCommit
                target = try await reading { try await loadCommit.execute(revision: commit.hash) }
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }
        if search.results?.contains(where: { $0.commit.hash == target.hash }) == false { clearSearch() }
        reveal(target)
    }

    public func closeFileInspector() {
        explorationTasks.inspection?.cancel()
        explorationTasks.fileDiff?.cancel()
        fileInspector = nil
    }

    public func waitForInspection() async {
        await explorationTasks.inspection?.value
        await explorationTasks.fileDiff?.value
    }

    func open(_ inspector: FileInspector) {
        explorationTasks.inspection?.cancel()
        explorationTasks.fileDiff?.cancel()
        inspection = FileInspection()
        fileInspector = inspector
    }
}
