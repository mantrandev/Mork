import Foundation

public struct BlamePrevious: Hashable, Sendable {
    public let hash: String
    public let path: String

    public init(hash: String, path: String) {
        self.hash = hash
        self.path = path
    }
}

public struct BlameCommit: Hashable, Sendable {
    public static let uncommittedHash = String(repeating: "0", count: 40)

    public let hash: String
    public let author: String
    public let date: Date
    public let summary: String
    public let isBoundary: Bool
    public let previous: BlamePrevious?

    public init(hash: String, author: String, date: Date, summary: String, isBoundary: Bool, previous: BlamePrevious?) {
        self.hash = hash
        self.author = author
        self.date = date
        self.summary = summary
        self.isBoundary = isBoundary
        self.previous = previous
    }

    public var isUncommitted: Bool { hash == Self.uncommittedHash }
    public var shortHash: String { String(hash.prefix(7)) }
}

public struct BlameLine: Identifiable, Hashable, Sendable {
    public let number: Int
    public let originalNumber: Int
    public let path: String
    public let content: String
    public let commit: BlameCommit

    public init(number: Int, originalNumber: Int, path: String, content: String, commit: BlameCommit) {
        self.number = number
        self.originalNumber = originalNumber
        self.path = path
        self.content = content
        self.commit = commit
    }

    public var id: Int { number }
}

public struct BlameBlock: Identifiable, Hashable, Sendable {
    public let index: Int
    public let commit: BlameCommit
    public let lines: [BlameLine]

    public init(index: Int, commit: BlameCommit, lines: [BlameLine]) {
        self.index = index
        self.commit = commit
        self.lines = lines
    }

    public var id: Int { index }
    public var isShaded: Bool { index % 2 == 1 }
}
