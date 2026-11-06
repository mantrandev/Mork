import MorkDomain
import Foundation

extension RepositoryViewModel {
    public var conflictWindowPosition: (index: Int, count: Int)? {
        guard let conflictWindowPath, let index = conflictedChanges.firstIndex(where: { $0.path == conflictWindowPath }) else { return nil }
        return (index, conflictedChanges.count)
    }

    public var conflictWindowResolver: ConflictResolverViewModel? {
        guard let conflictWindowPath, let conflictResolver, conflictResolver.path == conflictWindowPath else { return nil }
        return conflictResolver
    }

    public func toggleConflictWindow() {
        if conflictWindowPath != nil {
            closeConflictWindow()
        } else if let change = selectedConflict {
            isPreviewingFile = false
            showInConflictWindow(change.path)
        }
    }

    public func closeConflictWindow() {
        if conflictWindowPath != nil { conflictWindowPath = nil }
    }

    public func showNextConflict() {
        stepConflictWindow(by: 1)
    }

    public func showPreviousConflict() {
        stepConflictWindow(by: -1)
    }

    var selectedConflict: FileChange? {
        guard case let .file(change, staged) = selection, !staged, change.isConflicted else { return nil }
        return change
    }

    func followSelectionInConflictWindow() {
        if let change = selectedConflict, conflictWindowPath != nil || isPreviewingFile {
            isPreviewingFile = false
            showInConflictWindow(change.path)
            return
        }
        guard let shown = conflictWindowPath, conflictedChanges.contains(where: { $0.path == shown }) else { return }
        closeConflictWindow()
    }

    func advanceConflictWindow() {
        guard let shown = conflictWindowPath, !conflictedChanges.contains(where: { $0.path == shown }) else { return }
        let left = Set(conflictedChanges.map(\.path))
        let later = conflictWindowOrder.drop { $0 != shown }.dropFirst()
        let path = later.first(where: left.contains) ?? conflictedChanges.first?.path
        guard let path, let next = conflictedChanges.first(where: { $0.path == path }) else {
            closeConflictWindow()
            return
        }
        showInConflictWindow(next.path)
        selection = .file(next, staged: false)
    }

    private func stepConflictWindow(by offset: Int) {
        guard let position = conflictWindowPosition else { return }
        let target = position.index + offset
        guard conflictedChanges.indices.contains(target) else { return }
        selection = .file(conflictedChanges[target], staged: false)
    }

    private func showInConflictWindow(_ path: String) {
        conflictWindowOrder = conflictedChanges.map(\.path)
        if conflictWindowPath != path { conflictWindowPath = path }
    }
}
