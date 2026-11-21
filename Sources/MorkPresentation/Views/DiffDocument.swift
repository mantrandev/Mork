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
    static let largeByteCount = 1_048_576
    static let largeLineLength = DiffLine.maxDisplayLength
    static let empty = DiffDocument(lines: [], tabWidth: DiffMetrics.standard.tabWidth)

    struct Size: Equatable, Sendable {
        let lines: Int
        let bytes: Int
        let longestLine: Int

        var isLarge: Bool {
            lines > DiffDocument.largeLineCount || bytes > DiffDocument.largeByteCount || longestLine > DiffDocument.largeLineLength
        }
    }

    let lines: [DiffLine]
    let blocks: [DiffBlock]
    let lineNumberDigits: Int
    let maxColumns: Int
    let tabWidth: Int
    let totalLines: Int
    let byteCount: Int
    let isCollapsed: Bool
    let hasFileHeader: Bool
    let cost: Int

    var isLarge: Bool { totalLines > Self.largeLineCount }

    var sizeSummary: String {
        "\(totalLines.formatted()) lines, \(ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file))"
    }

    init(lines: [DiffLine], blocks: [DiffBlock], lineNumberDigits: Int, maxColumns: Int, tabWidth: Int, totalLines: Int, byteCount: Int, isCollapsed: Bool, hasFileHeader: Bool) {
        self.lines = lines
        self.blocks = blocks
        self.lineNumberDigits = lineNumberDigits
        self.maxColumns = maxColumns
        self.tabWidth = tabWidth
        self.totalLines = totalLines
        self.byteCount = byteCount
        self.isCollapsed = isCollapsed
        self.hasFileHeader = hasFileHeader
        cost = lines.reduce(lines.count * (MemoryLayout<DiffLine>.stride + MemoryLayout<DiffBlock>.stride)) { $0 + $1.text.utf8.count }
    }

    init(lines: [DiffLine], tabWidth: Int) {
        let largest = lines.lazy.flatMap { [$0.oldNumber, $0.newNumber] }.compactMap { $0 }.max()
        self.init(
            lines: lines,
            blocks: DiffBlock.blocks(from: lines),
            lineNumberDigits: largest.map { max(String($0).count, 3) } ?? 0,
            maxColumns: lines.map { DiffTabs.columns(of: $0.displayText, width: tabWidth) }.max() ?? 0,
            tabWidth: tabWidth,
            totalLines: lines.count,
            byteCount: lines.reduce(lines.count) { $0 + $1.text.utf8.count },
            isCollapsed: false,
            hasFileHeader: lines.contains(where: \.isFileHeader)
        )
    }

    static func make(text: String, patch: FilePatch?, isCommit: Bool, tabWidth: Int, showsLarge: Bool) -> DiffDocument {
        let size = size(of: text)
        let collapsed = size.isLarge && !showsLarge
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
            totalLines: size.lines,
            byteCount: size.bytes,
            isCollapsed: collapsed,
            hasFileHeader: hasFileHeader
        )
    }

    static func collapses(_ text: String, showsLarge: Bool) -> Bool {
        !showsLarge && size(of: text).isLarge
    }

    static func size(of text: String) -> Size {
        var count = 0
        var longest = 0
        var current = 0
        var last: UInt8 = 0
        for byte in text.utf8 {
            if byte == UInt8(ascii: "\n") {
                count += 1
                longest = max(longest, current)
                current = 0
            } else {
                current += 1
            }
            last = byte
        }
        longest = max(longest, current)
        let lines = text.isEmpty ? 0 : count + (last == UInt8(ascii: "\n") ? 0 : 1)
        return Size(lines: lines, bytes: text.utf8.count, longestLine: longest)
    }
}
