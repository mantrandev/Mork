import Foundation

public struct CommitRange: Hashable, Sendable {
    public static let emptyTree = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"

    public let oldest: Commit
    public let newest: Commit

    public init(oldest: Commit, newest: Commit) {
        self.oldest = oldest
        self.newest = newest
    }

    public var id: String { "\(oldest.hash)..\(newest.hash)" }
    public var startsAtRoot: Bool { oldest.parents.isEmpty }

    public func base(abbreviated: Bool = false) -> String {
        startsAtRoot ? Self.emptyTree : "\(Self.revision(oldest, abbreviated))^"
    }

    public func head(abbreviated: Bool = false) -> String {
        Self.revision(newest, abbreviated)
    }

    public func diffArguments(abbreviated: Bool = false) -> [String] {
        ["diff", base(abbreviated: abbreviated), head(abbreviated: abbreviated)]
    }

    public func patchArguments(folder: String, abbreviated: Bool = false) -> [String] {
        let range = startsAtRoot ? ["--root", head(abbreviated: abbreviated)] : ["\(base(abbreviated: abbreviated))..\(head(abbreviated: abbreviated))"]
        return ["format-patch", "-o", folder] + range
    }

    private static func revision(_ commit: Commit, _ abbreviated: Bool) -> String {
        abbreviated ? commit.shortHash : commit.hash
    }
}
