import MorkDomain
import Foundation

extension RepositoryViewModel {
    public var confirmsDestructiveActions: Bool { settings.confirmsDestructiveActions }
    public var isAutoFetching: Bool { autoFetch.task != nil }

    public func apply(_ settings: AppSettings) {
        let previous = self.settings
        if previous != settings { self.settings = settings }
        if previous.diff != settings.diff {
            preloader.clearDetails()
            workingDiffs.clear()
        }
        if previous.diff.options != settings.diff.options, selection != nil {
            reloadDetail()
        }
        if previous.autoFetch != settings.autoFetch || (settings.autoFetch != .off && !isAutoFetching) {
            restartAutoFetch()
        }
    }

    public func changeDiffSettings(_ change: (inout DiffSettings) -> Void) {
        var updated = settings
        change(&updated.diff)
        updated.diff = updated.diff.normalized()
        guard updated.diff != settings.diff else { return }
        apply(updated)
        onDiffSettingsChange?(updated.diff)
    }

    public func stopAutoFetch() {
        autoFetch.cancel()
    }

    public func showRepositorySettings() async {
        let session = RepositorySettingsViewModel(
            remotes: remotes,
            dependencies: dependencies.workspace.settings,
            onIgnoreSaved: { [weak self] in await self?.refresh() },
            onCommitTemplateSaved: { [weak self] in await self?.reloadCommitTemplate() }
        )
        repositorySettings = session
        await session.load()
    }

    private func restartAutoFetch() {
        autoFetch.cancel()
        guard let interval = settings.autoFetch.duration else { return }
        let sleep = sleep
        autoFetch.task = Task { [weak self] in
            while true {
                do {
                    try await sleep(interval)
                } catch {
                    return
                }
                guard !Task.isCancelled, let self else { return }
                await self.fetchAutomatically()
            }
        }
    }

    private func fetchAutomatically() async {
        guard !isBusy, !remotes.isEmpty else { return }
        await perform { dependencies in
            // Scheduled fetches retry on the next interval without interrupting the user.
            try? await dependencies.fetchRemotes.execute()
        }
    }
}

final class AutoFetchState {
    var task: Task<Void, Never>?

    func cancel() {
        task?.cancel()
        task = nil
    }

    deinit {
        task?.cancel()
    }
}
