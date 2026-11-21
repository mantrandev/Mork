import Foundation

public enum RepositoryChanges: Sendable, Equatable {
    case paths([String])
    case many

    public static let limit = 1_000

    public init(_ paths: [String], limit: Int = RepositoryChanges.limit) {
        self = paths.count > limit ? .many : .paths(paths)
    }

    public func merged(with other: RepositoryChanges, limit: Int = RepositoryChanges.limit) -> RepositoryChanges {
        guard case .paths(let mine) = self, case .paths(let theirs) = other else { return .many }
        return RepositoryChanges(mine + theirs, limit: limit)
    }
}
