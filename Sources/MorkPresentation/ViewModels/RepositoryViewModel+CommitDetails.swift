import MorkDomain
import Foundation

struct CommitFileRowsSource: Equatable {
    let files: [CommitFileChange]
    let mode: FileListMode
    let filter: String
}

enum InlineDiffState: Equatable {
    case loading
    case loaded(DiffDocument)
    case failed(String)
}

struct InlineDiffs {
    var hash: String?
    var expanded: Set<String> = []
    var states: [String: InlineDiffState] = [:]
}

struct CommitTabRow: Identifiable, Equatable {
    enum Detail: Equatable {
        case diff(DiffDocument)
        case large(Int)
        case failed(String)
    }

    let file: CommitFileChange
    let isExpanded: Bool
    let detail: Detail?

    var id: String { file.path }

    init(file: CommitFileChange, isExpanded: Bool, state: InlineDiffState?) {
        self.file = file
        self.isExpanded = isExpanded
        detail = switch isExpanded ? state : nil {
        case let .loaded(document): document.isCollapsed ? .large(document.totalLines) : .diff(document)
        case let .failed(message): .failed(message)
        case .loading, nil: nil
        }
    }
}

extension RepositoryViewModel {
    var currentCommitSummary: CommitSummary? {
        if case let .loaded(summary) = commitInfo, summary.commit == selectedCommit { return summary }
        return nil
    }

    func historyLane(of hash: String) -> Int? {
        if let searchRows { return searchRows.first { $0.id == hash }?.graph.column }
        guard let index = presentation.historyIndex[hash], historyRowModels.indices.contains(index) else { return nil }
        let row = historyRowModels[index]
        return row.id == hash ? row.graph.column : nil
    }

    func autoSelectChangesFile() {
        guard commitDetailsTab == .changes, !isMultiCommitSelection, case let .commit(commit) = selection,
              let summary = currentCommitSummary, let first = summary.files.first else { return }
        let file = lastChangesFilePath.flatMap { path in summary.files.first { $0.path == path } } ?? first
        selection = .commitFile(commit, file)
    }

    func rebuildCommitFileRows() {
        guard commitDetailsTab == .changes else { return }
        let source = CommitFileRowsSource(files: listedCommitSummary?.files ?? [], mode: commitFileListMode, filter: commitFileFilter)
        guard source != commitFileRowsSource else { return }
        commitFileRowsSource = source
        let rows = CommitFileList.rows(source.files, mode: source.mode, filter: source.filter)
        if rows != commitFileRows { commitFileRows = rows }
    }

    public func toggleInlineDiff(_ file: CommitFileChange) {
        guard let summary = currentCommitSummary, summary.files.contains(file) else { return }
        claimInlineDiffs(for: summary.commit)
        if inlineDiffs.expanded.remove(file.path) == nil {
            inlineDiffs.expanded.insert(file.path)
            loadInlineDiffs([file], in: summary.commit)
        }
        rebuildCommitTabRows()
    }

    public func expandAllInlineDiffs() {
        guard let summary = currentCommitSummary, !summary.files.isEmpty else { return }
        claimInlineDiffs(for: summary.commit)
        inlineDiffs.expanded = Set(summary.files.map(\.path))
        loadInlineDiffs(summary.files, in: summary.commit)
        rebuildCommitTabRows()
    }

    public func collapseAllInlineDiffs() {
        guard !inlineDiffs.expanded.isEmpty else { return }
        inlineDiffs.expanded = []
        rebuildCommitTabRows()
    }

    public func waitForInlineDiffs() async {
        while let task = inlineTasks.values.first {
            await task.value
        }
    }

    func resetInlineDiffs() {
        inlineTasks.values.forEach { $0.cancel() }
        inlineTasks = [:]
        inlineDiffs = InlineDiffs(hash: selectedCommit?.hash)
    }

    func rebuildCommitTabRows() {
        guard commitDetailsTab == .commit else { return }
        let files = listedCommitSummary?.files ?? []
        var rows: [CommitTabRow] = []
        rows.reserveCapacity(files.count)
        for file in files {
            rows.append(CommitTabRow(file: file, isExpanded: inlineDiffs.expanded.contains(file.path), state: inlineDiffs.states[file.path]))
        }
        if rows != commitTabRows { commitTabRows = rows }
        let allExpanded = !files.isEmpty && files.allSatisfy { inlineDiffs.expanded.contains($0.path) }
        if allExpanded != areAllInlineDiffsExpanded { areAllInlineDiffsExpanded = allExpanded }
    }

    func inlineDiffStates(of files: [CommitFileChange], in commit: Commit) async -> [String: InlineDiffState] {
        let tabWidth = settings.diff.tabWidth
        var states: [String: InlineDiffState] = [:]
        var remaining = files
        var ready = preloader.detail(of: commit.hash, tabWidth: tabWidth)
        if ready == nil, files.count > 1 {
            switch await commitDetailTask(for: commit).value {
            case let .success(detail): ready = detail
            case let .failure(error): return files.reduce(into: [:]) { $0[$1.path] = .failed(error.localizedDescription) }
            }
        }
        if let ready {
            remaining = files.filter { file in
                guard let prepared = ready.files[file.path] else { return true }
                states[file.path] = .loaded(prepared.document)
                return false
            }
        }
        let load = dependencies.loadCommitFileDiff
        for file in remaining {
            do {
                let text = try await load.execute(commit: commit, file: file)
                states[file.path] = .loaded(await Task.detached(priority: .userInitiated) {
                    DiffDocument.make(text: text, patch: nil, isCommit: false, tabWidth: tabWidth, showsLarge: false)
                }.value)
            } catch {
                states[file.path] = .failed(error.localizedDescription)
            }
        }
        return states
    }

    private func claimInlineDiffs(for commit: Commit) {
        guard inlineDiffs.hash != commit.hash else { return }
        resetInlineDiffs()
        inlineDiffs.hash = commit.hash
    }

    private func loadInlineDiffs(_ files: [CommitFileChange], in commit: Commit) {
        let missing = files.filter { file in
            switch inlineDiffs.states[file.path] {
            case .loaded, .loading: false
            case .failed, nil: true
            }
        }
        guard !missing.isEmpty else { return }
        let tabWidth = settings.diff.tabWidth
        if let ready = preloader.detail(of: commit.hash, tabWidth: tabWidth) {
            let remaining = fill(missing, from: ready)
            loadSeparately(remaining, in: commit)
            return
        }
        guard missing.count > 1 else {
            loadSeparately(missing, in: commit)
            return
        }
        for file in missing { inlineDiffs.states[file.path] = .loading }
        let whole = commitDetailTask(for: commit)
        track { [weak self] in
            let result = await whole.value
            guard let self, !Task.isCancelled, self.inlineDiffs.hash == commit.hash else { return }
            switch result {
            case let .success(ready):
                let remaining = self.fill(missing, from: ready)
                self.loadSeparately(remaining, in: commit)
            case let .failure(error):
                for file in missing { self.inlineDiffs.states[file.path] = .failed(error.localizedDescription) }
            }
            self.rebuildCommitTabRows()
        }
    }

    private func fill(_ files: [CommitFileChange], from ready: CommitPreloader.PreparedDetail) -> [CommitFileChange] {
        var remaining: [CommitFileChange] = []
        for file in files {
            if let prepared = ready.files[file.path] {
                inlineDiffs.states[file.path] = .loaded(prepared.document)
            } else {
                remaining.append(file)
            }
        }
        return remaining
    }

    private func loadSeparately(_ files: [CommitFileChange], in commit: Commit) {
        guard !files.isEmpty else { return }
        for file in files { inlineDiffs.states[file.path] = .loading }
        let load = dependencies.loadCommitFileDiff
        let tabWidth = settings.diff.tabWidth
        track { [weak self] in
            var results: [String: InlineDiffState] = [:]
            for file in files {
                do {
                    let text = try await load.execute(commit: commit, file: file)
                    let document = await Task.detached(priority: .userInitiated) {
                        DiffDocument.make(text: text, patch: nil, isCommit: false, tabWidth: tabWidth, showsLarge: false)
                    }.value
                    results[file.path] = .loaded(document)
                } catch {
                    results[file.path] = .failed(error.localizedDescription)
                }
                if Task.isCancelled { return }
            }
            guard let self, !Task.isCancelled, self.inlineDiffs.hash == commit.hash else { return }
            self.inlineDiffs.states.merge(results) { _, new in new }
            self.rebuildCommitTabRows()
        }
    }

    private func track(_ work: @escaping @MainActor () async -> Void) {
        let id = UUID()
        inlineTasks[id] = Task { [weak self] in
            await work()
            self?.inlineTasks[id] = nil
        }
    }
}
