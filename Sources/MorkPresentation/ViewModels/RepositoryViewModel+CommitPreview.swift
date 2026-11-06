import MorkDomain
import Foundation

extension RepositoryViewModel {
    public var previewedCommit: Commit? {
        isPreviewingCommit ? selectedCommit : nil
    }

    public func toggleCommitPreview() {
        isPreviewingCommit = !isPreviewingCommit && selectedCommit != nil
    }

    public func closeCommitPreview() {
        isPreviewingCommit = false
    }

    public func detachCommitPreview() -> RepositoryViewModel? {
        guard let commit = previewedCommit else { return nil }
        closeCommitPreview()
        let detached = RepositoryViewModel(url: url, dependencies: dependencies)
        var detachedSettings = settings
        detachedSettings.autoFetch = .off
        detached.apply(detachedSettings)
        detached.onDiffSettingsChange = onDiffSettingsChange
        detached.pane = .history
        detached.selection = .commit(commit)
        return detached
    }
}
