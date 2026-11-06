import Foundation

public protocol LoadRepositoryStatisticsUseCaseProtocol: Sendable {
    func execute(options: StatisticsOptions) async throws -> RepositoryStatistics
}

public final class LoadRepositoryStatisticsUseCase: LoadRepositoryStatisticsUseCaseProtocol {
    private let statistics: StatisticsRepositoryProtocol
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    public init(statistics: StatisticsRepositoryProtocol, calendar: Calendar = .current, now: @escaping @Sendable () -> Date = { Date() }) {
        self.statistics = statistics
        self.calendar = calendar
        self.now = now
    }

    public func execute(options: StatisticsOptions) async throws -> RepositoryStatistics {
        async let commits = statistics.commits()
        async let files = statistics.changedFiles(commitLimit: options.fileCommitLimit)
        async let references = statistics.referenceCounts()
        return try await StatisticsAggregator.aggregate(
            commits: commits,
            changedFiles: files,
            references: references,
            options: options,
            now: now(),
            calendar: calendar
        )
    }
}
