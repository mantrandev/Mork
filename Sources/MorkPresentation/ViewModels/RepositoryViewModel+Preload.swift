import MorkDomain
import Foundation

extension RepositoryViewModel {
    public static let commitPreloadCapacity = 32
    public static let hoverPrefetchDelay: Duration = .milliseconds(80)

    public func prefetchCommit(_ commit: Commit) {
        if preloader.summary(of: commit.hash) == nil { _ = summaryTask(for: commit) }
        if needsDetailPrefetch(commit) { _ = commitDetailTask(for: commit) }
    }

    private func needsDetailPrefetch(_ commit: Commit) -> Bool {
        commitDetailsTab == .changes && preloader.detail(of: commit.hash, tabWidth: settings.diff.tabWidth) == nil
    }

    public func endHover(_ commit: Commit) {
        guard preloader.hoveredHash == commit.hash else { return }
        hoverCommit(nil)
    }

    public func hoverCommit(_ commit: Commit?) {
        preloader.hoverTask?.cancel()
        preloader.hoverTask = nil
        preloader.hoveredHash = commit?.hash
        guard let commit, preloader.summary(of: commit.hash) == nil || needsDetailPrefetch(commit) else { return }
        let sleep = sleep
        preloader.hoverTask = Task { [weak self] in
            try? await sleep(Self.hoverPrefetchDelay)
            guard !Task.isCancelled else { return }
            self?.prefetchCommit(commit)
        }
    }

    public func waitForPrefetches() async {
        while case let tasks = preloader.pendingTasks + workingDiffs.pendingTasks, !tasks.isEmpty {
            for task in tasks { await task.value }
            preloader.hoverTask = nil
            workingDiffs.hoverTask = nil
        }
    }

    func prefetchNeighbors(of commit: Commit) {
        guard let index = presentation.historyIndex[commit.hash] else { return }
        for neighbor in [index - 1, index + 1] where historyRows.indices.contains(neighbor) {
            prefetchCommit(historyRows[neighbor].commit)
        }
    }

    func summaryTask(for commit: Commit) -> Task<Result<CommitSummary, Error>, Never> {
        let load = dependencies.loadCommitSummary
        let needsSignature = signatureBadges.status(of: commit.hash) != CommitSignature.none
        return preloader.loadSummary(commit.hash) {
            try await load.execute(commit: commit, needsSignature: needsSignature)
        }
    }

    func commitDetailTask(for commit: Commit) -> Task<Result<CommitPreloader.PreparedDetail, Error>, Never> {
        let load = dependencies.loadCommitDetails
        let tabWidth = settings.diff.tabWidth
        return preloader.loadDetail(commit.hash, tabWidth: tabWidth) {
            let text = try await load.execute(commit: commit)
            return await Task.detached(priority: .userInitiated) {
                CommitPreloader.PreparedDetail(
                    text: text,
                    document: DiffDocument.make(text: text, patch: nil, isCommit: true, tabWidth: tabWidth, showsLarge: false),
                    submoduleSummary: Self.submoduleSummary(of: text, path: nil),
                    lfsPointer: Self.lfsPointerChange(of: text),
                    tabWidth: tabWidth,
                    files: Self.preparedFiles(of: text, tabWidth: tabWidth)
                )
            }.value
        }
    }

    nonisolated static func preparedFiles(of text: String, tabWidth: Int) -> [String: CommitPreloader.PreparedFile] {
        CommitDiffSections.split(text).reduce(into: [:]) { files, section in
            files[section.key] = preparedFile(section.value, path: section.key, tabWidth: tabWidth)
        }
    }

    nonisolated static func preparedFile(_ text: String, path: String, tabWidth: Int) -> CommitPreloader.PreparedFile {
        CommitPreloader.PreparedFile(
            text: text,
            document: DiffDocument.make(text: text, patch: nil, isCommit: false, tabWidth: tabWidth, showsLarge: false),
            submoduleSummary: submoduleSummary(of: text, path: path),
            lfsPointer: lfsPointerChange(of: text)
        )
    }
}
