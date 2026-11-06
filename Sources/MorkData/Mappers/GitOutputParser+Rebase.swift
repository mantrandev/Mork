import MorkDomain
import Foundation

extension GitOutputParser {
    static let rebaseStepFormat = "%H%x1f%P%x1f%an%x1f%ae%x1f%at%x1f%D%x1f%s%x1f%B%x1e"

    static func rebaseSteps(_ output: String) -> [RebaseStep] {
        output.split(separator: recordSeparator).compactMap { record in
            let fields = record.drop { $0.isNewline }.split(separator: separator, maxSplits: 7, omittingEmptySubsequences: false).map(String.init)
            guard fields.count == 8, !fields[0].isEmpty else { return nil }
            let commit = Commit(
                hash: fields[0],
                parents: fields[1].split(separator: " ").map(String.init),
                author: fields[2],
                authorEmail: fields[3],
                date: Date(timeIntervalSince1970: TimeInterval(fields[4]) ?? 0),
                refs: fields[5],
                subject: fields[6]
            )
            return RebaseStep(commit: commit, originalMessage: fields[7].trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
