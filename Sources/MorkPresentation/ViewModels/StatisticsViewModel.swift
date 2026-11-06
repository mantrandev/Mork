import MorkDomain
import Foundation
import Observation

@MainActor
@Observable
public final class StatisticsViewModel: Identifiable {
    public static let fileCommitLimits = [100, 500, 1_000, 5_000]

    public let repositoryName: String
    public private(set) var state: Loadable<RepositoryStatistics> = .idle
    public private(set) var fileCommitLimit = StatisticsOptions.standard.fileCommitLimit

    private let loadStatistics: LoadRepositoryStatisticsUseCaseProtocol
    private var generation = 0

    public init(repositoryName: String, loadStatistics: LoadRepositoryStatisticsUseCaseProtocol) {
        self.repositoryName = repositoryName
        self.loadStatistics = loadStatistics
    }

    public var isEmptyRepository: Bool {
        guard case let .loaded(statistics) = state else { return false }
        return statistics.isEmpty
    }

    public func load() async {
        generation += 1
        let current = generation
        if case .idle = state { state = .loading }
        var options = StatisticsOptions.standard
        options.fileCommitLimit = fileCommitLimit
        let result: Loadable<RepositoryStatistics>
        do {
            result = .loaded(try await loadStatistics.execute(options: options))
        } catch {
            result = .failed(error.localizedDescription)
        }
        guard current == generation else { return }
        state = result
    }

    public func setFileCommitLimit(_ limit: Int) async {
        guard limit != fileCommitLimit else { return }
        fileCommitLimit = limit
        await load()
    }
}

public enum StatisticsText {
    private static let daysPerYear = 365
    private static let daysPerMonth = 30

    public static func age(days: Int?) -> String {
        guard let days else { return "—" }
        if days < 1 { return "less than a day" }
        if days <= daysPerMonth { return plural(days, "day") }
        let years = days / daysPerYear
        let months = (days % daysPerYear) / daysPerMonth
        guard years > 0 else { return plural(months, "month") }
        return months > 0 ? "\(plural(years, "year")), \(plural(months, "month"))" : plural(years, "year")
    }

    public static func commits(_ count: Int) -> String {
        plural(count, "commit")
    }

    public static func weekLabel(_ week: WeekActivity) -> String {
        "Week of \(week.start.formatted(date: .abbreviated, time: .omitted))"
    }

    public static func weekValue(_ week: WeekActivity) -> String {
        commits(week.commits)
    }

    public static func heatmapLabel(weekday: Int, hour: Int, count: Int) -> String {
        "\(ActivityHeatmap.weekdayNames[weekday]) \(String(format: "%02d", hour)):00, \(commits(count))"
    }

    private static func plural(_ count: Int, _ word: String) -> String {
        "\(count) \(word)\(count == 1 ? "" : "s")"
    }
}
