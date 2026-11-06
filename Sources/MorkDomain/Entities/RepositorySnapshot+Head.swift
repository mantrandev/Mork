import Foundation

extension RepositorySnapshot {
    private static let head = "HEAD"
    private static let headPrefix = "HEAD -> "

    public var headCommit: Commit? {
        commits.first { commit in
            commit.refNames.contains { $0 == Self.head || $0.hasPrefix(Self.headPrefix) }
        }
    }
}
