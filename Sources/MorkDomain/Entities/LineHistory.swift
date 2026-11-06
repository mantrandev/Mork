import Foundation

public struct LineHistoryRequest: Hashable, Sendable {
    public let path: String
    public let start: Int
    public let end: Int
    public let revision: String

    public init(path: String, start: Int, end: Int, revision: String) {
        self.path = path
        self.start = max(1, min(start, end))
        self.end = max(1, max(start, end))
        self.revision = revision
    }

    public var range: String { "\(start),\(end)" }
    public var lineDescription: String { start == end ? "line \(start)" : "lines \(start)–\(end)" }
}

public struct LineHistoryEntry: Identifiable, Hashable, Sendable {
    public let commit: Commit
    public let diff: String

    public init(commit: Commit, diff: String) {
        self.commit = commit
        self.diff = diff
    }

    public var id: String { commit.hash }
}
