import Foundation

public struct StatisticsAggregator: Sendable {
    private struct AuthorKey: Hashable, Sendable {
        let name: String
        let email: String
    }

    private struct AuthorTally: Sendable {
        var commits = 0
        var merges = 0
        var first: Int
        var last: Int
    }

    private static let secondsPerHour = 3_600
    private static let secondsPerDay = 86_400
    private static let thursdayOffsetFromMonday = 3

    private let now: Date
    private let weekStarts: [TimeInterval]
    private let weeksEnd: TimeInterval
    private var authors: [AuthorKey: AuthorTally] = [:]
    private var weekCounts: [Int]
    private var heatmap = Array(repeating: 0, count: ActivityHeatmap.weekdays * ActivityHeatmap.hours)
    private var fileCounts: [String: Int] = [:]
    private var commits = 0
    private var merges = 0
    private var first: Int?
    private var last: Int?

    public init(now: Date, calendar: Calendar, weeks: Int) {
        self.now = now
        let current = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        weekStarts = (0..<max(weeks, 0)).map { index in
            (calendar.date(byAdding: .weekOfYear, value: index - weeks + 1, to: current) ?? current).timeIntervalSince1970
        }
        weeksEnd = (calendar.date(byAdding: .weekOfYear, value: 1, to: current) ?? now).timeIntervalSince1970
        weekCounts = Array(repeating: 0, count: weekStarts.count)
    }

    public static func aggregate(
        commits: [StatisticsCommit],
        changedFiles: [String],
        references: ReferenceCounts,
        options: StatisticsOptions,
        now: Date,
        calendar: Calendar
    ) -> RepositoryStatistics {
        var aggregator = StatisticsAggregator(now: now, calendar: calendar, weeks: options.weeks)
        for commit in commits { aggregator.add(commit) }
        aggregator.addChangedFiles(changedFiles)
        return aggregator.result(references: references, topFileCount: options.topFileCount)
    }

    public mutating func add(_ commit: StatisticsCommit) {
        commits += 1
        if commit.isMerge { merges += 1 }
        first = min(first ?? commit.timestamp, commit.timestamp)
        last = max(last ?? commit.timestamp, commit.timestamp)
        let key = AuthorKey(name: commit.authorName, email: commit.authorEmail)
        var tally = authors[key] ?? AuthorTally(first: commit.timestamp, last: commit.timestamp)
        if commit.isMerge { tally.merges += 1 } else { tally.commits += 1 }
        tally.first = min(tally.first, commit.timestamp)
        tally.last = max(tally.last, commit.timestamp)
        authors[key] = tally
        if let week = weekIndex(of: TimeInterval(commit.timestamp)) { weekCounts[week] += 1 }
        heatmap[Self.heatmapIndex(timestamp: commit.timestamp, utcOffset: commit.utcOffset)] += 1
    }

    public mutating func addChangedFiles<Paths: Sequence>(_ paths: Paths) where Paths.Element == String {
        for path in paths { fileCounts[path, default: 0] += 1 }
    }

    public func result(references: ReferenceCounts, topFileCount: Int) -> RepositoryStatistics {
        let authorList = authors.map { key, tally in
            AuthorStatistics(
                name: key.name,
                email: key.email,
                commits: tally.commits,
                merges: tally.merges,
                firstDate: Date(timeIntervalSince1970: TimeInterval(tally.first)),
                lastDate: Date(timeIntervalSince1970: TimeInterval(tally.last))
            )
        }
        .sorted { lhs, rhs in
            if lhs.total != rhs.total { return lhs.total > rhs.total }
            let left = lhs.name.lowercased(), right = rhs.name.lowercased()
            if left != right { return left < right }
            return lhs.email < rhs.email
        }
        let topFiles = fileCounts
            .map { FileChangeCount(path: $0.key, changes: $0.value) }
            .sorted { $0.changes != $1.changes ? $0.changes > $1.changes : $0.path < $1.path }
            .prefix(max(topFileCount, 0))
        return RepositoryStatistics(
            totals: StatisticsTotals(
                commits: commits,
                merges: merges,
                authors: authors.count,
                branches: references.branches,
                tags: references.tags,
                firstCommit: first.map { Date(timeIntervalSince1970: TimeInterval($0)) },
                lastCommit: last.map { Date(timeIntervalSince1970: TimeInterval($0)) }
            ),
            authors: authorList,
            weeks: zip(weekStarts, weekCounts).map { WeekActivity(start: Date(timeIntervalSince1970: $0), commits: $1) },
            heatmap: ActivityHeatmap(counts: heatmap),
            topFiles: Array(topFiles),
            generatedAt: now
        )
    }

    private func weekIndex(of time: TimeInterval) -> Int? {
        guard let start = weekStarts.first, time >= start, time < weeksEnd else { return nil }
        var index = min(Int((time - start) / TimeInterval(7 * Self.secondsPerDay)), weekStarts.count - 1)
        while index > 0, time < weekStarts[index] { index -= 1 }
        while index + 1 < weekStarts.count, time >= weekStarts[index + 1] { index += 1 }
        return index
    }

    private static func heatmapIndex(timestamp: Int, utcOffset: Int) -> Int {
        let local = timestamp + utcOffset
        let day = floorDivide(local, secondsPerDay)
        let hour = (local - day * secondsPerDay) / secondsPerHour
        let weekday = modulo(day + thursdayOffsetFromMonday, ActivityHeatmap.weekdays)
        return weekday * ActivityHeatmap.hours + hour
    }

    private static func floorDivide(_ value: Int, _ divisor: Int) -> Int {
        let quotient = value / divisor
        return value % divisor < 0 ? quotient - 1 : quotient
    }

    private static func modulo(_ value: Int, _ divisor: Int) -> Int {
        let remainder = value % divisor
        return remainder < 0 ? remainder + divisor : remainder
    }
}
