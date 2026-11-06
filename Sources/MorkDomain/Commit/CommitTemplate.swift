import Foundation

public struct CommitTemplate: Equatable, Sendable {
    public static let defaultCommentPrefix = "#"

    public let text: String
    public let commentPrefix: String

    public init(text: String, commentPrefix: String = CommitTemplate.defaultCommentPrefix) {
        self.text = text
        self.commentPrefix = commentPrefix.isEmpty ? Self.defaultCommentPrefix : commentPrefix
    }

    public var composerMessage: CommitMessage {
        let body = text.replacingOccurrences(of: "\r\n", with: "\n")
        guard let newline = body.firstIndex(of: "\n") else { return CommitMessage(subject: body, description: "") }
        let description = body[body.index(after: newline)...].trimmingCharacters(in: .newlines)
        return CommitMessage(subject: String(body[..<newline]), description: description)
    }

    public func cleaned(_ message: String) -> String {
        CommitMessageCleanup.strip(message, commentPrefix: commentPrefix)
    }
}

public enum CommitMessageCleanup {
    public static func strip(_ message: String, commentPrefix: String) -> String {
        var lines: [String] = []
        for raw in message.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false) {
            guard !raw.hasPrefix(commentPrefix) else { continue }
            let line = String(raw.reversed().drop(while: \.isWhitespace).reversed())
            if line.isEmpty, lines.last?.isEmpty ?? true { continue }
            lines.append(line)
        }
        while lines.last?.isEmpty == true { lines.removeLast() }
        return lines.joined(separator: "\n")
    }
}
