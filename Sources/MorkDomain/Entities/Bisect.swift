import Foundation

public enum BisectMark: String, CaseIterable, Sendable {
    case good
    case bad
    case skip
}

public struct BisectCommit: Hashable, Sendable {
    public let hash: String
    public let subject: String

    public init(hash: String, subject: String) {
        self.hash = hash
        self.subject = subject
    }

    public var shortHash: String { String(hash.prefix(7)) }
}

public struct BisectProgress: Equatable, Sendable {
    public let remaining: Int
    public let steps: Int

    public init(remaining: Int, steps: Int) {
        self.remaining = remaining
        self.steps = steps
    }

    public var summary: String {
        let revisions = remaining == 1 ? "revision" : "revisions"
        let stepWord = steps == 1 ? "step" : "steps"
        return "Bisecting: \(remaining) \(revisions) left to test (about \(steps) \(stepWord))"
    }
}

public enum BisectWaiting: Sendable, Equatable {
    case goodAndBad
    case good
    case bad
}

public enum BisectState: Equatable, Sendable {
    case waiting(BisectWaiting)
    case testing(progress: BisectProgress?, candidate: BisectCommit?)
    case found(BisectCommit)
    case onlySkipped([BisectCommit])
}

public struct BisectLogEntry: Hashable, Sendable {
    public let mark: BisectMark
    public let commit: BisectCommit

    public init(mark: BisectMark, commit: BisectCommit) {
        self.mark = mark
        self.commit = commit
    }
}

public struct BisectLog: Equatable, Sendable {
    public let entries: [BisectLogEntry]
    public let state: BisectState

    public init(entries: [BisectLogEntry], state: BisectState) {
        self.entries = entries
        self.state = state
    }
}

public struct BisectSession: Equatable, Sendable {
    public let originalHead: String
    public let entries: [BisectLogEntry]
    public let state: BisectState

    public init(originalHead: String, entries: [BisectLogEntry], state: BisectState) {
        self.originalHead = originalHead
        self.entries = entries
        self.state = state
    }

    public var marks: [String: BisectMark] {
        entries.reduce(into: [:]) { $0[$1.commit.hash] = $1.mark }
    }

    public var candidate: BisectCommit? {
        guard case let .testing(_, candidate) = state else { return nil }
        return candidate
    }

    public var firstBad: BisectCommit? {
        guard case let .found(commit) = state else { return nil }
        return commit
    }
}

public enum BisectResetResult: Equatable, Sendable {
    case notBisecting
    case restored(String)
    case originalHeadMissing(String)
}

public enum BisectError: LocalizedError, Sendable, Equatable {
    case notBisecting

    public var errorDescription: String? {
        switch self {
        case .notBisecting:
            "No bisect is running. Start one with git bisect start, or mark a commit as good or bad."
        }
    }
}
