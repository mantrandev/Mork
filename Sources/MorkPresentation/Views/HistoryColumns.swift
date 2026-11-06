import Foundation

struct HistoryColumns: Equatable {
    static let authorWidth: Double = 160
    static let minimumAuthorWidth: Double = 60
    static let dateWidth: Double = 120
    static let hashWidth: Double = 64
    static let spacing: Double = Metrics.Spacing.s
    static let minimumSubjectWidth: Double = 240

    let author: Double
    let date: Double
    let hash: Double

    init(width: Double) {
        let fixed = Self.dateWidth + Self.hashWidth + Self.spacing * 3
        let room = width - fixed - Self.minimumSubjectWidth
        let author = min(Self.authorWidth, max(0, room))
        self.author = author < Self.minimumAuthorWidth ? 0 : author
        date = Self.dateWidth
        hash = Self.hashWidth
    }
}

enum CommitDateText {
    static func string(for date: Date, now: Date = Date(), calendar: Calendar = .current, locale: Locale = .current) -> String {
        let time = date.formatted(Date.VerbatimFormatStyle(
            format: "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
            locale: locale, timeZone: calendar.timeZone, calendar: calendar
        ))
        if calendar.isDate(date, inSameDayAs: now) { return "Today \(time)" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday \(time)"
        }
        let day = date.formatted(Date.VerbatimFormatStyle(
            format: "\(day: .defaultDigits) \(month: .abbreviated)",
            locale: locale, timeZone: calendar.timeZone, calendar: calendar
        ))
        if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            return "\(day) \(time)"
        }
        return "\(day) \(calendar.component(.year, from: date))"
    }
}
