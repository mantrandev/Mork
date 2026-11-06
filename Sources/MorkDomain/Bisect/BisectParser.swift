import Foundation

public enum BisectParser {
    private static let firstBadSuffix = " is the first bad commit"
    private static let onlySkippedPrefix = "There are only 'skip'ped commits left to test."
    private static let bisectingPrefix = "Bisecting: "
    private static let statusPrefix = "status: "
    private static let commentPrefix = "# "
    private static let markTerms: [String: BisectMark] = ["good": .good, "old": .good, "bad": .bad, "new": .bad, "skip": .skip]

    public static func outcome(_ output: String) -> BisectState? {
        let lines = output.split(whereSeparator: \.isNewline).map(String.init)
        var outcome: BisectState?
        for (index, line) in lines.enumerated() {
            if line.hasSuffix(firstBadSuffix), let hash = line.split(separator: " ").first.map(String.init), isHash(hash) {
                let subject = lines[(index + 1)...].first { $0.hasPrefix("    ") }?.trimmingCharacters(in: .whitespaces) ?? ""
                return .found(BisectCommit(hash: hash, subject: subject))
            }
            if line.hasPrefix(onlySkippedPrefix) {
                let hashes = lines[(index + 1)...].filter(isHash)
                return .onlySkipped(hashes.map { BisectCommit(hash: $0, subject: "") })
            }
            if line.hasPrefix(bisectingPrefix), index + 1 < lines.count, let candidate = bracketedCommit(lines[index + 1]) {
                outcome = .testing(progress: progress(bisectingLine: line), candidate: candidate)
            } else if line.hasPrefix(statusPrefix), let waiting = waiting(String(line.dropFirst(statusPrefix.count))) {
                outcome = .waiting(waiting)
            }
        }
        return outcome
    }

    public static func log(_ text: String) -> BisectLog {
        var entries: [BisectLogEntry] = []
        var state = BisectState.waiting(.goodAndBad)
        for line in text.split(whereSeparator: \.isNewline) where line.hasPrefix(commentPrefix) {
            let comment = String(line.dropFirst(commentPrefix.count))
            if comment.hasPrefix(statusPrefix) {
                if let waiting = waiting(String(comment.dropFirst(statusPrefix.count))) { state = .waiting(waiting) }
                continue
            }
            if comment.hasPrefix("only skipped commits left to test") {
                state = .onlySkipped([])
                continue
            }
            guard let separator = comment.range(of: ": "), let commit = bracketedCommit(String(comment[separator.upperBound...])) else { continue }
            let term = String(comment[..<separator.lowerBound])
            switch term {
            case "first bad commit":
                state = .found(commit)
            case "possible first bad commit":
                if case let .onlySkipped(commits) = state { state = .onlySkipped(commits + [commit]) }
            default:
                guard let mark = markTerms[term] else { continue }
                entries.append(BisectLogEntry(mark: mark, commit: commit))
                state = .testing(progress: nil, candidate: nil)
            }
        }
        return BisectLog(entries: entries, state: state)
    }

    public static func progress(bisectVars: String) -> BisectProgress? {
        var values: [String: Int] = [:]
        for line in bisectVars.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "=", maxSplits: 1)
            guard parts.count == 2, let value = Int(parts[1]) else { continue }
            values[String(parts[0])] = value
        }
        guard let remaining = values["bisect_nr"], let steps = values["bisect_steps"] else { return nil }
        return BisectProgress(remaining: remaining, steps: steps)
    }

    private static func progress(bisectingLine line: String) -> BisectProgress? {
        let words = line.split(separator: " ")
        guard words.count > 1, let remaining = Int(words[1]),
              let roughly = words.firstIndex(of: "(roughly"), roughly + 1 < words.count,
              let steps = Int(words[roughly + 1])
        else { return nil }
        return BisectProgress(remaining: remaining, steps: steps)
    }

    private static func waiting(_ status: String) -> BisectWaiting? {
        if status.hasPrefix("waiting for both good and bad commits") { return .goodAndBad }
        if status.hasPrefix("waiting for good commit") { return .good }
        if status.hasPrefix("waiting for bad commit") { return .bad }
        return nil
    }

    private static func bracketedCommit(_ text: String) -> BisectCommit? {
        guard text.hasPrefix("["), let close = text.firstIndex(of: "]") else { return nil }
        let hash = String(text[text.index(after: text.startIndex)..<close])
        guard isHash(hash) else { return nil }
        let subject = text[text.index(after: close)...].trimmingCharacters(in: .whitespaces)
        return BisectCommit(hash: hash, subject: subject)
    }

    private static func isHash(_ text: String) -> Bool {
        text.count >= 7 && text.allSatisfy(\.isHexDigit)
    }
}
