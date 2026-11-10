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

    func restartAutoFetch() {
        autoFetch.cancel()
        guard let interval = settings.autoFetch.duration else { return }
        let sleep = sleep
        let firstWait = autoFetch.remaining(of: interval, at: now())
        autoFetch.task = Task { [weak self] in
            var wait = firstWait
            while true {
                if wait > .zero {
                    do {
                        try await sleep(wait)
                    } catch {
                        return
                    }
                }
                guard !Task.isCancelled, let self else { return }
                await self.fetchAutomatically()
                wait = interval
            }
        }
    }

    private func fetchAutomatically() async {
        guard !isBusy, !remotes.isEmpty else { return }
        await perform { dependencies in
            try? await dependencies.fetchRemotes.execute()
        }
        autoFetch.lastAttempt = now()
    }
}

final class AutoFetchState {
    var task: Task<Void, Never>?
    var lastAttempt: ContinuousClock.Instant?

    func remaining(of interval: Duration, at now: ContinuousClock.Instant) -> Duration {
        guard let lastAttempt else { return .zero }
        return max(.zero, interval - lastAttempt.duration(to: now))
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    deinit {
        task?.cancel()
    }
}
