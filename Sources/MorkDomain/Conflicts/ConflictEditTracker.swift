import Foundation

public enum ConflictLineOrigin: Equatable, Sendable {
    case common
    case ours
    case theirs
    case unresolved
    case edited
}

public struct ConflictEditTracker: Sendable {
    public static let defaultMaximumEdits = 2_000

    private let lines: [String]
    private let lineOrigins: [ConflictLineOrigin]
    private let maximumEdits: Int

    public init(document: ConflictDocument, maximumEdits: Int = defaultMaximumEdits) {
        var lines: [String] = []
        var origins: [ConflictLineOrigin] = []
        func append(_ text: String, _ origin: ConflictLineOrigin) {
            let pieces = ConflictText.lines(text)
            lines += pieces
            origins += Array(repeating: origin, count: pieces.count)
        }
        for segment in document.segments {
            switch segment {
            case let .common(text):
                append(text, .common)
            case let .conflict(block):
                let raw = ConflictText.lines(block.raw)
                let ours = ConflictText.lines(block.ours).count
                let base = block.base.map { ConflictText.lines($0).count + 1 } ?? 0
                let theirs = ConflictText.lines(block.theirs).count
                lines += raw
                origins += [.unresolved]
                    + Array(repeating: .ours, count: ours)
                    + Array(repeating: .unresolved, count: base + 1)
                    + Array(repeating: .theirs, count: theirs)
                    + [.unresolved]
            }
        }
        self.lines = lines
        lineOrigins = origins
        self.maximumEdits = maximumEdits
    }

    public func origins(of text: String) -> [ConflictLineOrigin] {
        let current = ConflictText.lines(text)
        var result = Array(repeating: ConflictLineOrigin.edited, count: current.count)
        var prefix = 0
        while prefix < lines.count, prefix < current.count, lines[prefix] == current[prefix] {
            result[prefix] = lineOrigins[prefix]
            prefix += 1
        }
        var suffix = 0
        while suffix < lines.count - prefix, suffix < current.count - prefix, lines[lines.count - 1 - suffix] == current[current.count - 1 - suffix] {
            result[current.count - 1 - suffix] = lineOrigins[lines.count - 1 - suffix]
            suffix += 1
        }
        let old = lines[prefix..<(lines.count - suffix)]
        let new = current[prefix..<(current.count - suffix)]
        var used = Set<Int>()
        for (oldIndex, newIndex) in Self.matches(old, new, maximumEdits: maximumEdits) {
            result[newIndex] = lineOrigins[oldIndex]
            used.insert(oldIndex)
        }
        matchMovedSideLines(old, new, used: used, into: &result)
        return result
    }

    private func matchMovedSideLines(_ old: ArraySlice<String>, _ new: ArraySlice<String>, used: Set<Int>, into result: inout [ConflictLineOrigin]) {
        var unused: [String: [Int]] = [:]
        for index in old.indices.reversed() where !used.contains(index) && (lineOrigins[index] == .ours || lineOrigins[index] == .theirs) {
            unused[old[index], default: []].append(index)
        }
        guard !unused.isEmpty else { return }
        for index in new.indices where result[index] == .edited {
            guard let oldIndex = unused[new[index]]?.popLast() else { continue }
            result[index] = lineOrigins[oldIndex]
        }
    }

    private static func matches(_ old: ArraySlice<String>, _ new: ArraySlice<String>, maximumEdits: Int) -> [(Int, Int)] {
        guard !old.isEmpty, !new.isEmpty else { return [] }
        var ids: [String: Int] = [:]
        let oldIDs = old.map { line in
            if let id = ids[line] { return id }
            let id = ids.count
            ids[line] = id
            return id
        }
        let newIDs = new.map { ids[$0] ?? -1 }
        let shared = Set(newIDs)
        let oldKept = old.indices.filter { shared.contains(oldIDs[$0 - old.startIndex]) }
        let newKept = new.indices.filter { newIDs[$0 - new.startIndex] >= 0 }
        let pairs = myers(oldKept.map { oldIDs[$0 - old.startIndex] }, newKept.map { newIDs[$0 - new.startIndex] }, maximumEdits: maximumEdits)
        return pairs.map { (oldKept[$0.0], newKept[$0.1]) }
    }

    private static func myers(_ a: [Int], _ b: [Int], maximumEdits: Int) -> [(Int, Int)] {
        let n = a.count
        let m = b.count
        guard n > 0, m > 0 else { return [] }
        let limit = min(n + m, maximumEdits)
        let offset = limit + 1
        var v = [Int](repeating: 0, count: 2 * limit + 3)
        var trace: [Int32] = []
        for d in 0...limit {
            for k in stride(from: -d, through: d, by: 2) {
                var x = k == -d || (k != d && v[offset + k - 1] < v[offset + k + 1]) ? v[offset + k + 1] : v[offset + k - 1] + 1
                var y = x - k
                while x < n, y < m, a[x] == b[y] {
                    x += 1
                    y += 1
                }
                v[offset + k] = x
                if x >= n, y >= m { return backtrack(trace, edits: d, n: n, m: m) }
            }
            trace += v[(offset - d)...(offset + d)].map { Int32($0) }
        }
        return []
    }

    private static func backtrack(_ trace: [Int32], edits: Int, n: Int, m: Int) -> [(Int, Int)] {
        var pairs: [(Int, Int)] = []
        var x = n
        var y = m
        for d in stride(from: edits, to: 0, by: -1) {
            let k = x - y
            let base = (d - 1) * (d - 1) + (d - 1)
            func previous(_ diagonal: Int) -> Int { Int(trace[base + diagonal]) }
            let down = k == -d || (k != d && previous(k - 1) < previous(k + 1))
            let previousK = down ? k + 1 : k - 1
            let previousX = previous(previousK)
            let startX = down ? previousX : previousX + 1
            while x > startX, y > startX - k {
                x -= 1
                y -= 1
                pairs.append((x, y))
            }
            x = previousX
            y = previousX - previousK
        }
        while x > 0, y > 0 {
            x -= 1
            y -= 1
            pairs.append((x, y))
        }
        return pairs
    }
}
