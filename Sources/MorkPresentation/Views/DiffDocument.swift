import MorkDomain
import Foundation

enum DiffBlock: Identifiable, Equatable, Sendable {
    case file(DiffLine, meta: [DiffLine], additions: Int, deletions: Int)
    case hunk(DiffLine)
    case line(DiffLine)

    var id: Int {
        switch self {
        case let .file(line, _, _, _), let .hunk(line), let .line(line): line.id
        }
    }

    static func blocks(from lines: [DiffLine]) -> [DiffBlock] {
        var blocks: [DiffBlock] = []
        blocks.reserveCapacity(lines.count)
        var index = 0
        while index < lines.count {
            let line = lines[index]
            guard line.isFileHeader else {
                blocks.append(line.kind == .hunk ? .hunk(line) : .line(line))
                index += 1
                continue
            }
            var meta: [DiffLine] = []
            index += 1
            while index < lines.count, lines[index].kind == .meta, !lines[index].isFileHeader {
                meta.append(lines[index])
                index += 1
            }
            var end = index
            var additions = 0
            var deletions = 0
            while end < lines.count, !lines[end].isFileHeader {
                if lines[end].kind == .addition { additions += 1 }
                if lines[end].kind == .deletion { deletions += 1 }
                end += 1
            }
            blocks.append(.file(line, meta: meta, additions: additions, deletions: deletions))
        }
        return blocks
    }
}

struct DiffDocument: Equatable, Sendable {
    static let largeLineCount = DiffLine.maxLines
    static let empty = DiffDocument(lines: [], tabWidth: DiffMetrics.standard.tabWidth)

    let lines: [DiffLine]
    let blocks: [DiffBlock]
    let lineNumberDigits: Int
    let maxColumns: Int
    let tabWidth: Int
    let totalLines: Int
    let isCollapsed: Bool
    let hasFileHeader: Bool

    var isLarge: Bool { totalLines > Self.largeLineCount }

    init(lines: [DiffLine], blocks: [DiffBlock], lineNumberDigits: Int, maxColumns: Int, tabWidth: Int, totalLines: Int, isCollapsed: Bool, hasFileHeader: Bool) {
        self.lines = lines
        self.blocks = blocks
        self.lineNumberDigits = lineNumberDigits
        self.maxColumns = maxColumns
        self.tabWidth = tabWidth
        self.totalLines = totalLines
        self.isCollapsed = isCollapsed
        self.hasFileHeader = hasFileHeader
    }

    init(lines: [DiffLine], tabWidth: Int) {
        let largest = lines.lazy.flatMap { [$0.oldNumber, $0.newNumber] }.compactMap { $0 }.max()
        self.init(
            lines: lines,
            blocks: DiffBlock.blocks(from: lines),
            lineNumberDigits: largest.map { max(String($0).count, 3) } ?? 0,
            maxColumns: lines.map { DiffTabs.columns(of: $0.text, width: tabWidth) }.max() ?? 0,
            tabWidth: tabWidth,
            totalLines: lines.count,
            isCollapsed: false,
            hasFileHeader: lines.contains(where: \.isFileHeader)
        )
    }

    static func make(text: String, patch: FilePatch?, isCommit: Bool, tabWidth: Int, showsLarge: Bool) -> DiffDocument {
        let total = lineCount(of: text)
        let collapsed = total > largeLineCount && !showsLarge
        let parsed = collapsed ? [] : patch.map { DiffLine.parse($0, limit: nil) } ?? DiffLine.parse(text, limit: nil)
        let hasFileHeader = collapsed ? true : parsed.contains(where: \.isFileHeader)
        let lines = isCommit && hasFileHeader ? Array(parsed.drop { !$0.isFileHeader }) : parsed
        let document = DiffDocument(lines: lines, tabWidth: tabWidth)
        return DiffDocument(
            lines: lines,
            blocks: document.blocks,
            lineNumberDigits: document.lineNumberDigits,
            maxColumns: document.maxColumns,
            tabWidth: tabWidth,
            totalLines: total,
            isCollapsed: collapsed,
            hasFileHeader: hasFileHeader
        )
    }

    static func lineCount(of text: String) -> Int {
        var count = 0
        var last: UInt8 = 0
        for byte in text.utf8 {
            if byte == UInt8(ascii: "\n") { count += 1 }
            last = byte
        }
        return text.isEmpty ? 0 : count + (last == UInt8(ascii: "\n") ? 0 : 1)
    }
}
