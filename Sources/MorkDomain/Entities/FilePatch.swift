import Foundation

public struct DiffHunk: Identifiable, Hashable, Sendable {
    public let index: Int
    public let header: String
    public let oldStart: Int
    public let oldCount: Int
    public let newStart: Int
    public let newCount: Int
    public let lines: [String]

    public init(index: Int, header: String, oldStart: Int, oldCount: Int, newStart: Int, newCount: Int, lines: [String]) {
        self.index = index
        self.header = header
        self.oldStart = oldStart
        self.oldCount = oldCount
        self.newStart = newStart
        self.newCount = newCount
        self.lines = lines
    }

    public var id: Int { index }
}

public struct FilePatch: Hashable, Sendable {
    public let header: [String]
    public let hunks: [DiffHunk]

    public init(header: [String], hunks: [DiffHunk]) {
        self.header = header
        self.hunks = hunks
    }

    public func patch(for hunk: DiffHunk) -> String {
        (header + [hunk.header] + hunk.lines).joined(separator: "\n") + "\n"
    }
}

public enum HunkAction: String, CaseIterable, Sendable {
    case stage
    case unstage
    case discard

    public static func available(for change: FileChange, staged: Bool) -> [HunkAction] {
        guard !change.isConflicted else { return [] }
        return staged ? [.unstage] : [.stage, .discard]
    }
}
