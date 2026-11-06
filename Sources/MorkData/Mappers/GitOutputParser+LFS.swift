import MorkDomain
import Foundation

extension GitOutputParser {
    static func lfsTrackedPatterns(_ output: String) -> [String] {
        var patterns: [String] = []
        var inTracked = false
        for line in output.split(whereSeparator: \.isNewline) {
            if line.hasPrefix("Listing tracked patterns") {
                inTracked = true
                continue
            }
            if line.hasPrefix("Listing") {
                inTracked = false
                continue
            }
            guard inTracked, line.first?.isWhitespace == true else { continue }
            var entry = line.trimmingCharacters(in: .whitespaces)
            if entry.hasSuffix(")"), let open = entry.range(of: " (", options: .backwards) {
                entry = String(entry[..<open.lowerBound])
            }
            if !entry.isEmpty, !patterns.contains(entry) { patterns.append(entry) }
        }
        return patterns
    }

    static func lfsFilteredPaths(_ output: String) -> Set<String> {
        let fields = output.split(separator: "\0", omittingEmptySubsequences: false)
        var paths: Set<String> = []
        var index = 0
        while index + 2 < fields.count {
            if fields[index + 1] == "filter", fields[index + 2] == "lfs" {
                paths.insert(String(fields[index]))
            }
            index += 3
        }
        return paths
    }
}
