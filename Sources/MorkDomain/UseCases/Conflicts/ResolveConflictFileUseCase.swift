import Foundation

public protocol ResolveConflictFileUseCaseProtocol: Sendable {
    func execute(change: FileChange, resolution: ConflictFileResolution) async throws
}

public final class ResolveConflictFileUseCase: ResolveConflictFileUseCaseProtocol {
    private let conflicts: ConflictRepositoryProtocol

    public init(conflicts: ConflictRepositoryProtocol) {
        self.conflicts = conflicts
    }

    public func execute(change: FileChange, resolution: ConflictFileResolution) async throws {
        guard let kind = change.conflictKind else { throw ConflictError.notConflicted(path: change.path) }
        guard kind.resolutions.contains(resolution) else { throw ConflictError.unavailable(resolution, kind) }
        switch resolution {
        case .ours:
            try await conflicts.checkout(.ours, path: change.path)
            try await conflicts.markResolved(path: change.path)
        case .theirs:
            try await conflicts.checkout(.theirs, path: change.path)
            try await conflicts.markResolved(path: change.path)
        case .keep:
            try await conflicts.markResolved(path: change.path)
        case .delete:
            try await conflicts.remove(path: change.path)
        }
    }
}
