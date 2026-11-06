import Foundation

public enum LinePatchBuilder {
    private static let defaultMarker = "\\ No newline at end of file"
    private static let droppedHeaderPrefixes = ["index ", "old mode ", "new mode "]

    private struct Row {
        enum Kind {
            case context
            case removed
            case added
        }

        var kind: Kind
        let content: Substring.UnicodeScalarView
        var missingNewline = false
        var marker = LinePatchBuilder.defaultMarker

        var rendered: [String] {
            let prefix: Unicode.Scalar = switch kind {
            case .context: " "
            case .removed: "-"
            case .added: "+"
            }
            var line = String.UnicodeScalarView()
            line.append(prefix)
            line.append(contentsOf: content)
            return missingNewline ? [String(line), marker] : [String(line)]
        }
    }

    public static func patch(for file: FilePatch, selection: DiffLineSelection, action: HunkAction) -> String? {
        let reverse = action != .stage
        var body: [String] = []
        var delta = 0
        var oldTotal = 0
        var newTotal = 0
        for hunk in file.hunks {
            let chosen = selection.lines(inHunk: hunk.index)
            guard !chosen.isEmpty, let rows = rows(of: hunk, selecting: chosen, reverse: reverse) else { continue }
            let oldCount = rows.count { $0.kind != .added }
            let newCount = rows.count { $0.kind != .removed }
            let oldStart: Int
            let newStart: Int
            if reverse {
                newStart = hunk.newStart
                oldStart = start(after: anchor(hunk.newStart, hunk.newCount) + delta, count: oldCount)
                delta += oldCount - newCount
            } else {
                oldStart = hunk.oldStart
                newStart = start(after: anchor(hunk.oldStart, hunk.oldCount) + delta, count: newCount)
                delta += newCount - oldCount
            }
            oldTotal += oldCount
            newTotal += newCount
            body.append("@@ -\(oldStart),\(oldCount) +\(newStart),\(newCount) @@" + suffix(of: hunk.header))
            body += rows.flatMap(\.rendered)
        }
        guard !body.isEmpty else { return nil }
        return (header(of: file, oldTotal: oldTotal, newTotal: newTotal) + body).joined(separator: "\n") + "\n"
    }

    private static func rows(of hunk: DiffHunk, selecting chosen: IndexSet, reverse: Bool) -> [Row]? {
        var rows: [Row] = []
        var previousKept = false
        for (index, line) in hunk.lines.enumerated() {
            var scalars = line.unicodeScalars[...]
            let marker = scalars.popFirst()
            if marker == "\\" {
                if previousKept, !rows.isEmpty {
                    rows[rows.count - 1].missingNewline = true
                    rows[rows.count - 1].marker = line
                }
                continue
            }
            let selected = chosen.contains(index)
            let kind: Row.Kind?
            switch marker {
            case "-": kind = selected ? .removed : (reverse ? nil : .context)
            case "+": kind = selected ? .added : (reverse ? .context : nil)
            default: kind = .context
            }
            previousKept = kind != nil
            if let kind { rows.append(Row(kind: kind, content: scalars)) }
        }
        guard rows.contains(where: { $0.kind != .context }) else { return nil }
        return reverse ? fixingReverseNewlines(rows) : fixingForwardNewlines(rows)
    }

    private static func fixingForwardNewlines(_ rows: [Row]) -> [Row] {
        var rows = rows
        guard let index = rows.firstIndex(where: { $0.kind == .context && $0.missingNewline }),
              let next = rows[(index + 1)...].firstIndex(where: { $0.kind != .removed })
        else { return rows }
        rows[index].kind = .removed
        let follower = rows[next]
        let isTwin = follower.kind == .added && !follower.missingNewline && Array(follower.content) == Array(rows[index].content)
        if !isTwin {
            rows.insert(Row(kind: .added, content: rows[index].content), at: index + 1)
        }
        return rows
    }

    private static func fixingReverseNewlines(_ rows: [Row]) -> [Row] {
        var rows = rows
        for index in rows.indices where rows[index].kind == .removed && rows[index].missingNewline {
            if rows[(index + 1)...].contains(where: { $0.kind != .added }) {
                rows[index].missingNewline = false
            }
        }
        return rows
    }

    private static func anchor(_ start: Int, _ count: Int) -> Int {
        count == 0 ? start : start - 1
    }

    private static func start(after anchor: Int, count: Int) -> Int {
        count == 0 ? anchor : anchor + 1
    }

    private static func suffix(of header: String) -> String {
        guard let plus = header.range(of: " +"), let end = header.range(of: " @@", range: plus.upperBound..<header.endIndex) else { return "" }
        return String(header[end.upperBound...])
    }

    private static func header(of file: FilePatch, oldTotal: Int, newTotal: Int) -> [String] {
        let keepsCreation = !file.header.contains("--- /dev/null") || oldTotal == 0
        let keepsDeletion = !file.header.contains("+++ /dev/null") || newTotal == 0
        let newPath = file.header.first { $0.hasPrefix("+++ ") }.map { swapSide(of: $0.dropFirst(4), from: "b", to: "a") }
        let oldPath = file.header.first { $0.hasPrefix("--- ") }.map { swapSide(of: $0.dropFirst(4), from: "a", to: "b") }
        return file.header.compactMap { line in
            if droppedHeaderPrefixes.contains(where: line.hasPrefix) { return nil }
            if !keepsCreation {
                if line.hasPrefix("new file mode ") { return nil }
                if line == "--- /dev/null", let newPath { return "--- " + newPath }
            }
            if !keepsDeletion {
                if line.hasPrefix("deleted file mode ") { return nil }
                if line == "+++ /dev/null", let oldPath { return "+++ " + oldPath }
            }
            return line
        }
    }

    private static func swapSide(of path: Substring, from: String, to: String) -> String {
        if path.hasPrefix("\"\(from)/") { return "\"\(to)/" + path.dropFirst(3) }
        if path.hasPrefix("\(from)/") { return "\(to)/" + path.dropFirst(2) }
        return String(path)
    }
}
