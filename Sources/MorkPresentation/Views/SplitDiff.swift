import Foundation

struct SplitDiffRow: Identifiable, Equatable, Sendable {
    enum Content: Equatable, Sendable {
        case hunk(DiffLine)
        case pair(left: DiffLine?, right: DiffLine?)
    }

    let id: Int
    let content: Content
}

enum SplitDiff {
    static func rows(from lines: [DiffLine]) -> [SplitDiffRow] {
        var contents: [SplitDiffRow.Content] = []
        var deletions: [DiffLine] = []
        var additions: [DiffLine] = []

        func flush() {
            for index in 0..<max(deletions.count, additions.count) {
                contents.append(.pair(
                    left: deletions.indices.contains(index) ? side(deletions[index]) : nil,
                    right: additions.indices.contains(index) ? side(additions[index]) : nil
                ))
            }
            deletions = []
            additions = []
        }

        for line in lines where !line.text.hasPrefix("\\") {
            switch line.kind {
            case .meta:
                continue
            case .hunk:
                flush()
                contents.append(.hunk(line))
            case .deletion:
                if !additions.isEmpty { flush() }
                deletions.append(line)
            case .addition:
                additions.append(line)
            case .context:
                flush()
                let shown = side(line)
                contents.append(.pair(left: shown, right: shown))
            }
        }
        flush()
        return contents.enumerated().map { SplitDiffRow(id: $0.offset, content: $0.element) }
    }

    static func side(_ line: DiffLine) -> DiffLine {
        guard line.kind != .hunk, let first = line.text.first, first == "+" || first == "-" || first == " " else { return line }
        return DiffLine(
            id: line.id,
            text: String(line.text.dropFirst()),
            kind: line.kind,
            hunk: line.hunk,
            oldNumber: line.oldNumber,
            newNumber: line.newNumber,
            changed: line.changed.map { max(0, $0.lowerBound - 1)..<max(0, $0.upperBound - 1) },
            source: line.source
        )
    }
}
