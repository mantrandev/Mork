import MorkDomain
import Foundation

extension GitOutputParser {
    static func configEntries(_ output: String) -> [String: String] {
        var entries: [String: String] = [:]
        for record in output.split(separator: "\0") {
            let parts = record.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            guard let key = parts.first, !key.isEmpty else { continue }
            entries[String(key)] = parts.count > 1 ? String(parts[1]) : ""
        }
        return entries
    }
}
