import MorkDomain
import Foundation

struct DiffLine: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case addition
        case deletion
        case hunk
        case meta
        case context
    }

    static let maxLines = 5000
    static let maxHighlightLength = 1000

    let id: Int
    let text: String
    let kind: Kind
    var hunk: Int? = nil
    var oldNumber: Int? = nil
    var newNumber: Int? = nil
    var changed: Range<Int>? = nil
    var source: DiffLineID? = nil

    var isFileHeader: Bool { kind == .meta && text.hasPrefix("diff ") }

    static func parse(_ patch: FilePatch, limit: Int? = maxLines) -> [DiffLine] {
        var rows = patch.header.map { ($0, Kind.meta, Int?.none, DiffLineID?.none) }
        for hunk in patch.hunks {
            rows.append((hunk.header, .hunk, hunk.index, nil))
            rows += hunk.lines.enumerated().map { offset, line in
                (line, bodyKind(line), nil, line.hasPrefix("\\") ? nil : DiffLineID(hunk: hunk.index, line: offset))
            }
        }
        var counter = LineCounter()
        var hunkStarts = patch.hunks.makeIterator()
        let lines = rows.prefix(limit ?? rows.count).enumerated().map { offset, row in
            if row.1 == .hunk, let hunk = hunkStarts.next() {
                counter.start(old: hunk.oldStart, new: hunk.newStart)
            }
            return counter.number(DiffLine(id: offset, text: display(row.0), kind: row.1, hunk: row.2, source: row.3))
        }
        return highlightingChanges(lines)
    }

    static func parse(_ text: String, limit: Int? = maxLines) -> [DiffLine] {
        var lines = text.unicodeScalars.split(separator: "\n", omittingEmptySubsequences: false).map { String(Substring($0)) }
        if text.unicodeScalars.last == "\n" { lines.removeLast() }
        var inFileHeader = false
        var counter = LineCounter()
        let parsed = lines.prefix(limit ?? lines.count).enumerated().map { offset, line in
            let kind: Kind
            if line.hasPrefix("diff ") {
                inFileHeader = true
                counter.stop()
                kind = .meta
            } else if line.hasPrefix("@@") {
                inFileHeader = false
                counter.start(header: line)
                kind = .hunk
            } else if inFileHeader {
                kind = .meta
            } else {
                kind = bodyKind(line)
            }
            return counter.number(DiffLine(id: offset, text: display(line), kind: kind))
        }
        return highlightingChanges(parsed)
    }

    static func content(_ text: String) -> [DiffLine] {
        var lines = text.unicodeScalars.split(separator: "\n", omittingEmptySubsequences: false).map { String(Substring($0)) }
        if text.unicodeScalars.last == "\n" { lines.removeLast() }
        return lines.enumerated().map { offset, line in
            DiffLine(id: offset, text: display(line), kind: .context, newNumber: offset + 1)
        }
    }

    static func hunkLines(around id: Int, in lines: [DiffLine]) -> [DiffLine] {
        guard let index = lines.firstIndex(where: { $0.id == id }), lines[index].isHunkBody else { return [] }
        var start = index
        while start > lines.startIndex, lines[start - 1].isHunkBody { start -= 1 }
        var end = index
        while end + 1 < lines.endIndex, lines[end + 1].isHunkBody { end += 1 }
        return Array(lines[start...end])
    }

    var isHunkBody: Bool { kind == .addition || kind == .deletion || kind == .context }

    static func filePath(fromHeader header: String) -> String {
        if let range = header.range(of: " b/", options: .backwards) {
            return String(header[range.upperBound...])
        }
        for prefix in ["diff --git ", "diff --cc ", "diff --combined ", "diff "] where header.hasPrefix(prefix) {
            return String(header.dropFirst(prefix.count))
        }
        return header
    }

    private static func bodyKind(_ line: String) -> Kind {
        if line.hasPrefix("+") { return .addition }
        if line.hasPrefix("-") { return .deletion }
        return .context
    }

    private static func display(_ line: String) -> String {
        LosslessText.displayable(line.unicodeScalars.last == "\r" ? String(line.unicodeScalars.dropLast()) : line)
    }

    private static func highlightingChanges(_ lines: [DiffLine]) -> [DiffLine] {
        var result = lines
        var index = 0
        while index < result.count {
            guard result[index].kind == .deletion else {
                index += 1
                continue
            }
            let deletions = index
            while index < result.count, result[index].kind == .deletion { index += 1 }
            let additions = index
            while index < result.count, result[index].kind == .addition { index += 1 }
            let pairs = min(additions - deletions, index - additions)
            for offset in 0..<pairs {
                let old = deletions + offset
                let new = additions + offset
                guard let ranges = WordDiff.changedRanges(Array(result[old].text.dropFirst()), Array(result[new].text.dropFirst())) else { continue }
                result[old].changed = ranges.old.map { ($0.lowerBound + 1)..<($0.upperBound + 1) }
                result[new].changed = ranges.new.map { ($0.lowerBound + 1)..<($0.upperBound + 1) }
            }
        }
        return result
    }
}

private struct LineCounter {
    private var old: Int?
    private var new: Int?

    mutating func start(old: Int, new: Int) {
        self.old = old
        self.new = new
    }

    mutating func start(header: String) {
        let fields = header.split(separator: " ")
        guard fields.count >= 3, fields[1].hasPrefix("-"), fields[2].hasPrefix("+"),
              let old = Self.start(of: fields[1]), let new = Self.start(of: fields[2]) else {
            stop()
            return
        }
        start(old: old, new: new)
    }

    mutating func stop() {
        old = nil
        new = nil
    }

    mutating func number(_ line: DiffLine) -> DiffLine {
        guard let old, let new else { return line }
        var numbered = line
        switch line.kind {
        case .context where !line.text.hasPrefix("\\"):
            numbered.oldNumber = old
            numbered.newNumber = new
            self.old = old + 1
            self.new = new + 1
        case .deletion:
            numbered.oldNumber = old
            self.old = old + 1
        case .addition:
            numbered.newNumber = new
            self.new = new + 1
        default:
            break
        }
        return numbered
    }

    private static func start(of field: Substring) -> Int? {
        Int(field.dropFirst().split(separator: ",", maxSplits: 1).first ?? "")
    }
}

enum WordDiff {
    static func changedRanges(_ old: [Character], _ new: [Character]) -> (old: Range<Int>?, new: Range<Int>?)? {
        guard old != new, old.count <= DiffLine.maxHighlightLength, new.count <= DiffLine.maxHighlightLength else { return nil }
        let limit = min(old.count, new.count)
        var prefix = 0
        while prefix < limit, old[prefix] == new[prefix] { prefix += 1 }
        while prefix > 0, isWord(old[prefix - 1]), isWord(at: prefix, in: old) || isWord(at: prefix, in: new) { prefix -= 1 }
        var suffix = 0
        while suffix < limit - prefix, old[old.count - 1 - suffix] == new[new.count - 1 - suffix] { suffix += 1 }
        while suffix > 0, isWord(old[old.count - suffix]), isWord(at: old.count - suffix - 1, in: old) || isWord(at: new.count - suffix - 1, in: new) {
            suffix -= 1
        }
        guard prefix + suffix > 0 else { return nil }
        let oldRange = prefix..<(old.count - suffix)
        let newRange = prefix..<(new.count - suffix)
        return (oldRange.isEmpty ? nil : oldRange, newRange.isEmpty ? nil : newRange)
    }

    private static func isWord(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }

    private static func isWord(at index: Int, in characters: [Character]) -> Bool {
        characters.indices.contains(index) && isWord(characters[index])
    }
}
