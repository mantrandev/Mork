import Foundation

public struct SubmoduleDiff: Equatable, Sendable {
    private static let gitlinkMode = "160000"
    private static let marker = "Subproject commit "
    private static let dirtySuffix = "-dirty"

    public let oldCommit: String?
    public let newCommit: String?
    public let isDirty: Bool

    public init(oldCommit: String?, newCommit: String?, isDirty: Bool) {
        self.oldCommit = oldCommit
        self.newCommit = newCommit
        self.isDirty = isDirty
    }

    public static func parse(_ diff: String) -> SubmoduleDiff? {
        var hasOtherMode = false
        var old: String?
        var new: String?
        var isDirty = false
        var inHunk = false
        for line in diff.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line.hasPrefix("@@") {
                inHunk = true
                continue
            }
            guard inHunk else {
                if let mode = declaredMode(in: line), mode != gitlinkMode { hasOtherMode = true }
                continue
            }
            if line.isEmpty || line.hasPrefix("\\") { continue }
            if line.hasPrefix("diff --git") { return nil }
            let sign = line.prefix(1)
            let body = line.dropFirst()
            guard sign == "-" || sign == "+", body.hasPrefix(marker) else { return nil }
            var commit = String(body.dropFirst(marker.count))
            if commit.hasSuffix(dirtySuffix) {
                commit.removeLast(dirtySuffix.count)
                if sign == "+" { isDirty = true }
            }
            if sign == "-" { old = commit } else { new = commit }
        }
        guard !hasOtherMode, old != nil || new != nil else { return nil }
        return SubmoduleDiff(oldCommit: old, newCommit: new, isDirty: isDirty)
    }

    private static func declaredMode(in line: String) -> String? {
        let words = line.split(separator: " ")
        guard let last = words.last, last.count == 6, last.allSatisfy(\.isNumber) else { return nil }
        if line.hasPrefix("index "), words.count == 3 { return String(last) }
        if line.hasPrefix("new file mode ") || line.hasPrefix("deleted file mode ") || line.hasPrefix("old mode ") || line.hasPrefix("new mode ") {
            return String(last)
        }
        return nil
    }

    public func summary(path: String) -> String {
        let from = oldCommit.map { String($0.prefix(7)) } ?? "none"
        let to = newCommit.map { String($0.prefix(7)) } ?? "none"
        return "Submodule \(path): \(from) → \(to)" + (isDirty ? " (modified content)" : "")
    }
}
