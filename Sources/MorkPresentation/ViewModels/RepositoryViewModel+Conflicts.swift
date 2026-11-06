import MorkDomain
import Foundation

extension RepositoryViewModel {
    public var hasConflicts: Bool { !conflictedChanges.isEmpty }
    public var canConcludeMerge: Bool { repositoryState == .merging && !hasConflicts }

    public var conflictSummary: String {
        switch conflictedChanges.count {
        case 0: "All conflicts resolved."
        case 1: "1 conflicted file left."
        case let count: "\(count) conflicted files left."
        }
    }

    public var commitBlockedNote: String? {
        guard conflictResolver != nil else { return nil }
        switch conflictedChanges.count {
        case 0: return nil
        case 1: return "1 conflicted file left · resolve it to commit"
        case let count: return "\(count) conflicted files left · resolve them to commit"
        }
    }

    public func resolve(_ change: FileChange, using resolution: ConflictFileResolution) async {
        await performConflictAction(on: change.path) { try await $0.resolveConflictFile.execute(change: change, resolution: resolution) }
    }

    public func concludeMerge() async {
        await perform { try await $0.conflicts.concludeMerge.execute() }
    }

    func showConflictResolver() -> Bool {
        let conflicted = Set(conflictedChanges.map(\.path))
        conflictResolvers = conflictResolvers.filter { conflicted.contains($0.key) }
        guard case let .file(change, staged) = selection, !staged, change.isConflicted else {
            conflictResolver = nil
            return false
        }
        let resolver: ConflictResolverViewModel
        if let cached = conflictResolvers[change.path] {
            resolver = cached
        } else {
            let path = change.path
            resolver = ConflictResolverViewModel(change: change, loadConflict: dependencies.conflicts.loadConflict, debounce: filterDebounce) { [weak self] body in
                await self?.performConflictAction(on: path, body) ?? false
            }
            conflictResolvers[path] = resolver
        }
        if conflictResolver !== resolver { conflictResolver = resolver }
        resolver.reload(change, isRebasing: repositoryState == .rebasing)
        return true
    }

    @discardableResult
    private func performConflictAction(on path: String, _ body: @escaping @Sendable (ConflictDependencies) async throws -> Void) async -> Bool {
        let wasSelected = conflictResolver?.path == path
        let succeeded = await perform { try await body($0.conflicts) }
        if wasSelected, selection == nil, let next = conflictedChanges.first {
            selection = .file(next, staged: false)
        }
        return succeeded
    }
}
