import Foundation

public struct StatisticsCommit: Equatable, Sendable {
    public let parentCount: Int
    public let authorName: String
    public let authorEmail: String
    public let timestamp: Int
    public let utcOffset: Int

    public init(parentCount: Int, authorName: String, authorEmail: String, timestamp: Int, utcOffset: Int) {
        self.parentCount = parentCount
        self.authorName = authorName
        self.authorEmail = authorEmail
        self.timestamp = timestamp
        self.utcOffset = utcOffset
    }

    public var isMerge: Bool { parentCount > 1 }
}

public struct ReferenceCounts: Equatable, Sendable {
    public let branches: Int
    public let tags: Int

    public init(branches: Int, tags: Int) {
        self.branches = branches
        self.tags = tags
    }
}

public struct StatisticsOptions: Equatable, Sendable {
    public var fileCommitLimit: Int
    public var topFileCount: Int
    public var weeks: Int

    public init(fileCommitLimit: Int = 1_000, topFileCount: Int = 20, weeks: Int = 52) {
        self.fileCommitLimit = fileCommitLimit
        self.topFileCount = topFileCount
        self.weeks = weeks
    }

    public static let standard = StatisticsOptions()
}

public struct AuthorStatistics: Identifiable, Hashable, Sendable {
    public let name: String
    public let email: String
    public let commits: Int
    public let merges: Int
    public let firstDate: Date
    public let lastDate: Date

    public init(name: String, email: String, commits: Int, merges: Int, firstDate: Date, lastDate: Date) {
        self.name = name
        self.email = email
        self.commits = commits
        self.merges = merges
        self.firstDate = firstDate
        self.lastDate = lastDate
    }

    public var id: String { "\(name)\u{1f}\(email)" }
    public var total: Int { commits + merges }
}

public struct WeekActivity: Identifiable, Hashable, Sendable {
    public let start: Date
    public let commits: Int

    public init(start: Date, commits: Int) {
        self.start = start
        self.commits = commits
    }

    public var id: Date { start }
}

public struct ActivityHeatmap: Equatable, Sendable {
    public static let weekdays = 7
    public static let hours = 24
    public static let weekdayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    public let counts: [Int]

    public init(counts: [Int] = Array(repeating: 0, count: weekdays * hours)) {
        self.counts = counts
    }

    public func count(weekday: Int, hour: Int) -> Int {
        counts[weekday * Self.hours + hour]
    }

    public var maximum: Int { counts.max() ?? 0 }
}

public struct FileChangeCount: Identifiable, Hashable, Sendable {
    public let path: String
    public let changes: Int

    public init(path: String, changes: Int) {
        self.path = path
        self.changes = changes
    }

    public var id: String { path }
}

public struct StatisticsTotals: Equatable, Sendable {
    public let commits: Int
    public let merges: Int
    public let authors: Int
    public let branches: Int
    public let tags: Int
    public let firstCommit: Date?
    public let lastCommit: Date?

    public init(commits: Int, merges: Int, authors: Int, branches: Int, tags: Int, firstCommit: Date?, lastCommit: Date?) {
        self.commits = commits
        self.merges = merges
        self.authors = authors
        self.branches = branches
        self.tags = tags
        self.firstCommit = firstCommit
        self.lastCommit = lastCommit
    }
}

public struct RepositoryStatistics: Equatable, Sendable {
    public let totals: StatisticsTotals
    public let authors: [AuthorStatistics]
    public let weeks: [WeekActivity]
    public let heatmap: ActivityHeatmap
    public let topFiles: [FileChangeCount]
    public let generatedAt: Date

    public init(totals: StatisticsTotals, authors: [AuthorStatistics], weeks: [WeekActivity], heatmap: ActivityHeatmap, topFiles: [FileChangeCount], generatedAt: Date) {
        self.totals = totals
        self.authors = authors
        self.weeks = weeks
        self.heatmap = heatmap
        self.topFiles = topFiles
        self.generatedAt = generatedAt
    }

    private static let secondsPerDay: TimeInterval = 86_400

    public var isEmpty: Bool { totals.commits == 0 }

    public var ageInDays: Int? {
        totals.firstCommit.map { Int(generatedAt.timeIntervalSince($0) / Self.secondsPerDay) }
    }
}
