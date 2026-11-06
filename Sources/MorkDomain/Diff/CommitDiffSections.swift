import Foundation

public enum CommitDiffSections {
    public static func split(_ text: String) -> [String: String] {
        var sections: [String: String] = [:]
        for patch in DiffParser.parse(text) {
            let path = DiffFileSummary(header: patch.header, additions: 0, deletions: 0).path
            guard !path.isEmpty, sections[path] == nil else { continue }
            var lines = patch.header
            for hunk in patch.hunks {
                lines.append(hunk.header)
                lines.append(contentsOf: hunk.lines)
            }
            sections[path] = lines.joined(separator: "\n") + "\n"
        }
        return sections
    }
}
