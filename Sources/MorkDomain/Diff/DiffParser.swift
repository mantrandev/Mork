import Foundation

public enum DiffParser {
    private struct OpenHunk {
        let header: String
        let ranges: [Int]
        var lines: [String] = []
        var oldLeft: Int
        var newLeft: Int

        init(header: String, ranges: [Int]) {
            self.header = header
            self.ranges = ranges
            oldLeft = ranges[1]
            newLeft = ranges[3]
        }

        mutating func consume(_ line: String) -> Bool {
            let first = line.unicodeScalars.first
            if first == "\\" {
                lines.append(line)
                return true
            }
            switch first {
            case " ", nil:
                guard oldLeft > 0, newLeft > 0 else { return false }
                oldLeft -= 1
                newLeft -= 1
            case "-":
                guard oldLeft > 0 else { return false }
                oldLeft -= 1
            case "+":
                guard newLeft > 0 else { return false }
                newLeft -= 1
            default:
                return false
            }
            lines.append(line)
            return true
        }

        func close(index: Int) -> DiffHunk {
            DiffHunk(
                index: index, header: header,
                oldStart: ranges[0], oldCount: ranges[1], newStart: ranges[2], newCount: ranges[3],
                lines: lines
            )
        }
    }

    public static func parse(_ text: String) -> [FilePatch] {
        var lines = text.unicodeScalars.split(separator: "\n", omittingEmptySubsequences: false).map { String(Substring($0)) }
        if text.unicodeScalars.last == "\n" { lines.removeLast() }

        var files: [FilePatch] = []
        var header: [String] = []
        var hunks: [DiffHunk] = []
        var open: OpenHunk?
        var inFile = false

        func closeHunk() {
            if let hunk = open { hunks.append(hunk.close(index: hunks.count)) }
            open = nil
        }

        func closeFile() {
            closeHunk()
            if inFile { files.append(FilePatch(header: header, hunks: hunks)) }
            header = []
            hunks = []
        }

        for line in lines {
            if open?.consume(line) == true { continue }
            closeHunk()
            if line.hasPrefix("diff ") {
                closeFile()
                inFile = true
                header = [line]
            } else if inFile, let ranges = ranges(of: line) {
                open = OpenHunk(header: line, ranges: ranges)
            } else if inFile, hunks.isEmpty {
                header.append(line)
            }
        }
        closeFile()
        return files
    }

    private static func ranges(of line: String) -> [Int]? {
        guard line.hasPrefix("@@ -") else { return nil }
        let rest = line.dropFirst(4)
        guard let plus = rest.range(of: " +"),
              let end = rest.range(of: " @@", range: plus.upperBound..<rest.endIndex),
              let old = span(rest[..<plus.lowerBound]),
              let new = span(rest[plus.upperBound..<end.lowerBound])
        else { return nil }
        return old + new
    }

    private static func span(_ text: Substring) -> [Int]? {
        let parts = text.split(separator: ",", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count), let start = Int(parts[0]), start >= 0 else { return nil }
        guard parts.count == 2 else { return [start, 1] }
        guard let count = Int(parts[1]), count >= 0 else { return nil }
        return [start, count]
    }
}
