import Foundation

public struct DiffLineID: Hashable, Comparable, Sendable {
    public let hunk: Int
    public let line: Int

    public init(hunk: Int, line: Int) {
        self.hunk = hunk
        self.line = line
    }

    public static func < (lhs: DiffLineID, rhs: DiffLineID) -> Bool {
        (lhs.hunk, lhs.line) < (rhs.hunk, rhs.line)
    }
}

public struct DiffLineSelection: Hashable, Sendable {
    private var lines: [Int: IndexSet] = [:]

    public init() {}

    public init(_ ids: [DiffLineID]) {
        ids.forEach { insert($0) }
    }

    public var isEmpty: Bool { lines.isEmpty }
    public var count: Int { lines.values.reduce(0) { $0 + $1.count } }
    public var hunks: [Int] { lines.keys.sorted() }

    public func contains(_ id: DiffLineID) -> Bool {
        lines[id.hunk]?.contains(id.line) ?? false
    }

    public func lines(inHunk hunk: Int) -> IndexSet {
        lines[hunk] ?? IndexSet()
    }

    public mutating func insert(_ id: DiffLineID) {
        lines[id.hunk, default: IndexSet()].insert(id.line)
    }

    public mutating func toggle(_ id: DiffLineID) {
        guard contains(id) else { return insert(id) }
        lines[id.hunk]?.remove(id.line)
        if lines[id.hunk]?.isEmpty == true { lines[id.hunk] = nil }
    }

    public mutating func insertRange(from start: DiffLineID, to end: DiffLineID, in patch: FilePatch) {
        let (low, high) = start < end ? (start, end) : (end, start)
        for hunk in patch.hunks where hunk.index >= low.hunk && hunk.index <= high.hunk && !hunk.lines.isEmpty {
            let first = hunk.index == low.hunk ? low.line : 0
            let last = hunk.index == high.hunk ? min(high.line, hunk.lines.count - 1) : hunk.lines.count - 1
            guard first <= last else { continue }
            lines[hunk.index, default: IndexSet()].insert(integersIn: first...last)
        }
    }

    public func hasChanges(in patch: FilePatch) -> Bool {
        patch.hunks.contains { hunk in
            lines[hunk.index]?.contains { index in
                guard hunk.lines.indices.contains(index) else { return false }
                let marker = hunk.lines[index].unicodeScalars.first
                return marker == "+" || marker == "-"
            } ?? false
        }
    }
}
