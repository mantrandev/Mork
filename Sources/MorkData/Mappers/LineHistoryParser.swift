import MorkDomain
import Foundation

enum LineHistoryParser {
    static func arguments(_ request: LineHistoryRequest, limit: Int) -> [String] {
        ["log", "-L\(request.range):\(request.path)", "-n", "\(limit)", "--pretty=format:%x1e\(GitOutputParser.historyFormat)", request.revision]
    }

    static func parse(_ output: String) -> [LineHistoryEntry] {
        output.split(separator: GitOutputParser.recordSeparator).compactMap { record in
            let parts = record.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            guard let header = parts.first, let commit = GitOutputParser.commits(String(header)).first else { return nil }
            let diff = parts.count > 1 ? parts[1].trimmingCharacters(in: .newlines) : ""
            return LineHistoryEntry(commit: commit, diff: diff.isEmpty ? "" : diff + "\n")
        }
    }
}
