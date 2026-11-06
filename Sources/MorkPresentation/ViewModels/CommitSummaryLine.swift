import MorkDomain
import Foundation

struct CommitSummaryLine: Equatable {
    static let hashLength = 9

    let author: String
    let shortHash: String
    let date: String
    let subject: String

    init(commit: Commit, locale: Locale = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent) {
        author = commit.author.isEmpty ? "Unknown Author" : commit.author
        shortHash = String(commit.hash.prefix(Self.hashLength))
        var style = Date.FormatStyle.dateTime.day().month(.abbreviated).year().hour().minute()
        style.locale = locale
        style.timeZone = timeZone
        date = commit.date.formatted(style)
        subject = commit.subject.isEmpty ? "(no subject)" : commit.subject
    }

    static func fullDate(_ date: Date, locale: Locale = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        var style = Date.FormatStyle.dateTime.day().month(.wide).year().hour().minute().second().timeZone(.localizedGMT(.short))
        style.locale = locale
        style.timeZone = timeZone
        return date.formatted(style)
    }
}
