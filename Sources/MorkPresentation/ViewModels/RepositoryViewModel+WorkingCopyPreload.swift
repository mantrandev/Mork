import MorkDomain
import Foundation

extension RepositoryViewModel {
    public func prefetchChange(_ change: FileChange, staged: Bool) {
        _ = workingDiffTask(for: WorkingCopyDiffCache.Key(change: change, staged: staged))
    }

    public func hoverChange(_ change: FileChange?, staged: Bool) {
        workingDiffs.hoverTask?.cancel()
        workingDiffs.hoverTask = nil
        guard let change, !workingDiffs.isKnown(WorkingCopyDiffCache.Key(change: change, staged: staged)) else { return }
        let sleep = sleep
        workingDiffs.hoverTask = Task { [weak self] in
            try? await sleep(Self.hoverPrefetchDelay)
            guard !Task.isCancelled else { return }
            self?.prefetchChange(change, staged: staged)
        }
    }

    func prefetchChangeNeighbors() {
        guard case let .file(change, staged) = selection else { return }
        let files = changeRows(staged: staged).compactMap(\.file)
        guard let index = files.firstIndex(where: { $0.path == change.path }) else { return }
        for neighbor in [index - 1, index + 1] where files.indices.contains(neighbor) {
            prefetchChange(files[neighbor], staged: staged)
        }
    }

    func workingDiffTask(for key: WorkingCopyDiffCache.Key) -> Task<LoadedDetail, Never> {
        let selection = Selection.file(key.change, staged: key.staged)
        let request = DetailRequest(selection: selection, dependencies: dependencies, tabWidth: settings.diff.tabWidth, showsLarge: false, path: key.change.path, amending: isAmending)
        return workingDiffs.load(key) { await Self.fetchDetail(request) }
    }
}
