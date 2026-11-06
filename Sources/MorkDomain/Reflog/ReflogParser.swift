import Foundation

public enum ReflogParser {
    public static let format = "%H%x1f%P%x1f%an%x1f%at%x1f%D%x1f%gd%x1f%gs%x1f%s"

    private static let separator: Character = "\u{1f}"
    private static let actionSeparator = ": "
    private static let fieldCount = 8

    public static func parse(_ output: String) -> [ReflogEntry] {
        var entries: [ReflogEntry] = []
        for line in output.split(separator: "\n") {
            let fields = line.split(separator: separator, omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= fieldCount, !fields[0].isEmpty else { continue }
            let authorDate = Date(timeIntervalSince1970: TimeInterval(fields[3]) ?? 0)
            let commit = Commit(
                hash: fields[0],
                parents: fields[1].split(separator: " ").map(String.init),
                author: fields[2],
                date: authorDate,
                refs: fields[4],
                subject: fields[7...].joined(separator: String(separator))
            )
            let (reference, time) = selector(fields[5])
            let (action, message) = split(fields[6])
            entries.append(ReflogEntry(
                selector: "\(reference)@{\(entries.count)}",
                commit: commit,
                action: action,
                message: message,
                date: time.map { Date(timeIntervalSince1970: $0) } ?? authorDate
            ))
        }
        return entries
    }

    private static func selector(_ text: String) -> (reference: String, time: TimeInterval?) {
        guard let open = text.range(of: "@{"), text.hasSuffix("}") else { return (text, nil) }
        let value = text[open.upperBound..<text.index(before: text.endIndex)]
        return (String(text[..<open.lowerBound]), TimeInterval(value))
    }

    private static func split(_ subject: String) -> (action: String, message: String) {
        guard let range = subject.range(of: actionSeparator) else { return (subject, "") }
        return (String(subject[..<range.lowerBound]), String(subject[range.upperBound...]))
    }
}
