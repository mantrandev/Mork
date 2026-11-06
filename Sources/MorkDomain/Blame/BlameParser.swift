import Foundation

public enum BlameParser {
    private struct Header {
        let hash: String
        let originalNumber: Int
        let number: Int
    }

    private struct Details {
        var author = ""
        var time: TimeInterval = 0
        var summary = ""
        var isBoundary = false
        var previous: BlamePrevious?
        var path = ""

        func commit(hash: String) -> BlameCommit {
            BlameCommit(hash: hash, author: author, date: Date(timeIntervalSince1970: time), summary: summary, isBoundary: isBoundary, previous: previous)
        }
    }

    public static func parse(_ output: String) -> [BlameLine] {
        var details: [String: Details] = [:]
        var header: Header?
        var lines: [BlameLine] = []

        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("\t") {
                guard let current = header, let info = details[current.hash] else { continue }
                lines.append(BlameLine(
                    number: current.number,
                    originalNumber: current.originalNumber,
                    path: info.path,
                    content: String(line.dropFirst()),
                    commit: info.commit(hash: current.hash)
                ))
                header = nil
            } else if let parsed = self.header(line) {
                header = parsed
                if details[parsed.hash] == nil { details[parsed.hash] = Details() }
            } else if let current = header {
                apply(line, to: &details[current.hash, default: Details()])
            }
        }
        return lines.sorted { $0.number < $1.number }
    }

    public static func blocks(_ lines: [BlameLine]) -> [BlameBlock] {
        var blocks: [BlameBlock] = []
        var pending: [BlameLine] = []

        func close() {
            guard let first = pending.first else { return }
            blocks.append(BlameBlock(index: blocks.count, commit: first.commit, lines: pending))
            pending = []
        }

        for line in lines {
            if let last = pending.last, last.commit.hash != line.commit.hash { close() }
            pending.append(line)
        }
        close()
        return blocks
    }

    private static func header(_ line: Substring) -> Header? {
        let parts = line.split(separator: " ")
        guard (3...4).contains(parts.count),
              parts[0].count == 40,
              parts[0].allSatisfy(\.isHexDigit),
              let original = Int(parts[1]),
              let number = Int(parts[2])
        else { return nil }
        return Header(hash: String(parts[0]), originalNumber: original, number: number)
    }

    private static func apply(_ line: Substring, to details: inout Details) {
        let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        let key = parts[0]
        let value = parts.count > 1 ? String(parts[1]) : ""
        switch key {
        case "author": details.author = value
        case "author-time": details.time = TimeInterval(value) ?? 0
        case "summary": details.summary = value
        case "boundary": details.isBoundary = true
        case "filename": details.path = value
        case "previous":
            let previous = value.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
            if previous.count == 2 { details.previous = BlamePrevious(hash: String(previous[0]), path: String(previous[1])) }
        default: break
        }
    }
}
