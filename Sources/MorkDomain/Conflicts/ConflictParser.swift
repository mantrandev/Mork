import Foundation

public enum ConflictParser {
    public static let markerLength = 7

    private static let binaryProbeLength = 8_000
    private static let newline = UInt8(ascii: "\n")
    private static let carriageReturn = UInt8(ascii: "\r")
    private static let space = UInt8(ascii: " ")
    private static let tab = UInt8(ascii: "\t")

    private enum Marker {
        case start(String)
        case base(String)
        case separator
        case end(String)
    }

    private enum Section {
        case outside
        case ours
        case base
        case theirs
    }

    public static func content(of data: Data) -> ConflictContent {
        if data.prefix(binaryProbeLength).contains(0) { return .binary }
        let text = String(decoding: data, as: UTF8.self)
        guard text.utf8.elementsEqual(data) else { return .binary }
        return .text(parse(text))
    }

    public static func parse(_ text: String) -> ConflictDocument {
        let bytes = Array(text.utf8)
        var segments: [ConflictSegment] = []
        var section = Section.outside
        var commonStart = 0
        var blockStart = 0
        var oursStart = 0
        var oursEnd = 0
        var baseStart: Int?
        var baseEnd = 0
        var theirsStart = 0
        var oursLabel = ""
        var baseLabel: String?
        var lineStart = 0
        var blockCount = 0

        func string(_ range: Range<Int>) -> String {
            String(decoding: bytes[range], as: UTF8.self)
        }

        while lineStart < bytes.count {
            let newlineIndex = bytes[lineStart...].firstIndex(of: newline)
            let nextLine = newlineIndex.map { $0 + 1 } ?? bytes.count
            var contentEnd = newlineIndex ?? bytes.count
            if contentEnd > lineStart, bytes[contentEnd - 1] == carriageReturn { contentEnd -= 1 }
            let marker = marker(in: bytes, from: lineStart, to: contentEnd)

            switch (section, marker) {
            case let (_, .start(label)?):
                blockStart = lineStart
                oursStart = nextLine
                oursLabel = label
                baseStart = nil
                baseLabel = nil
                section = .ours
            case let (.ours, .base(label)?):
                oursEnd = lineStart
                baseStart = nextLine
                baseLabel = label
                section = .base
            case (.ours, .separator?):
                oursEnd = lineStart
                theirsStart = nextLine
                section = .theirs
            case (.base, .separator?):
                baseEnd = lineStart
                theirsStart = nextLine
                section = .theirs
            case let (.theirs, .end(label)?):
                if blockStart > commonStart { segments.append(.common(string(commonStart..<blockStart))) }
                let block = ConflictBlock(
                    index: blockCount,
                    ours: string(oursStart..<oursEnd),
                    base: baseStart.map { string($0..<baseEnd) },
                    theirs: string(theirsStart..<lineStart),
                    oursLabel: oursLabel,
                    baseLabel: baseLabel,
                    theirsLabel: label,
                    raw: string(blockStart..<nextLine)
                )
                segments.append(.conflict(block))
                blockCount += 1
                commonStart = nextLine
                section = .outside
            default:
                break
            }
            lineStart = nextLine
        }

        if commonStart < bytes.count { segments.append(.common(string(commonStart..<bytes.count))) }
        return ConflictDocument(segments: segments, lineEnding: lineEnding(in: bytes))
    }

    private static func marker(in bytes: [UInt8], from start: Int, to end: Int) -> Marker? {
        guard end - start >= markerLength else { return nil }
        let character = bytes[start]
        guard [UInt8(ascii: "<"), UInt8(ascii: "|"), UInt8(ascii: "="), UInt8(ascii: ">")].contains(character) else { return nil }
        for offset in 1..<markerLength where bytes[start + offset] != character {
            return nil
        }
        let afterMarker = start + markerLength
        if afterMarker < end, bytes[afterMarker] != space, bytes[afterMarker] != tab { return nil }
        let label = afterMarker < end
            ? String(decoding: bytes[(afterMarker + 1)..<end], as: UTF8.self).trimmingCharacters(in: .whitespaces)
            : ""
        switch character {
        case UInt8(ascii: "<"): return .start(label)
        case UInt8(ascii: "|"): return .base(label)
        case UInt8(ascii: "="): return .separator
        default: return .end(label)
        }
    }

    private static func lineEnding(in bytes: [UInt8]) -> String {
        guard let index = bytes.firstIndex(of: newline), index > 0, bytes[index - 1] == carriageReturn else { return "\n" }
        return "\r\n"
    }
}

public enum ConflictText {
    public static func lines(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        var slices = text.utf8.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: false)
        if text.utf8.last == UInt8(ascii: "\n") { slices.removeLast() }
        return slices.map { slice in
            let trimmed = slice.last == UInt8(ascii: "\r") ? slice.dropLast() : slice[...]
            return String(decoding: trimmed, as: UTF8.self)
        }
    }
}
