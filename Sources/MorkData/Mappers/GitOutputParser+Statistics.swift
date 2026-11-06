import MorkDomain
import Foundation

extension GitOutputParser {
    static let statisticsFormat = "%P%x1f%aN%x1f%aE%x1f%ad"

    private static let secondsPerHour = 3_600
    private static let secondsPerMinute = 60

    static func statisticsCommits(_ output: String) -> [StatisticsCommit] {
        var commits: [StatisticsCommit] = []
        output.enumerateLines { line, _ in
            let fields = line.split(separator: separator, maxSplits: 3, omittingEmptySubsequences: false)
            guard fields.count == 4 else { return }
            let date = fields[3].split(separator: " ")
            guard let timestamp = date.first.flatMap({ Int($0) }) else { return }
            commits.append(StatisticsCommit(
                parentCount: fields[0].split(separator: " ").count,
                authorName: String(fields[1]),
                authorEmail: String(fields[2]),
                timestamp: timestamp,
                utcOffset: date.count > 1 ? utcOffset(date[1]) : 0
            ))
        }
        return commits
    }

    static func changedPaths(_ output: String) -> [String] {
        output.split(separator: "\0").compactMap { token in
            let path = token.drop { $0.isNewline }
            return path.isEmpty ? nil : String(path)
        }
    }

    static func referenceCounts(_ output: String) -> ReferenceCounts {
        let references = lines(output)
        return ReferenceCounts(
            branches: references.filter { $0.hasPrefix("refs/heads/") }.count,
            tags: references.filter { $0.hasPrefix("refs/tags/") }.count
        )
    }

    private static func utcOffset(_ zone: Substring) -> Int {
        guard zone.count == 5, let sign = zone.first, sign == "+" || sign == "-",
              let hours = Int(zone.dropFirst().prefix(2)), let minutes = Int(zone.suffix(2))
        else { return 0 }
        let seconds = hours * secondsPerHour + minutes * secondsPerMinute
        return sign == "-" ? -seconds : seconds
    }
}
