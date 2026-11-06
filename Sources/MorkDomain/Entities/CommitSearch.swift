import Foundation

public enum CommitSearchMode: String, CaseIterable, Codable, Sendable {
    case message
    case author
    case hash
    case content
    case regex
}

public struct CommitSearchQuery: Hashable, Sendable {
    public let mode: CommitSearchMode
    public let text: String

    public init(mode: CommitSearchMode, text: String) {
        self.mode = mode
        self.text = text
    }

    public var term: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    public var isEmpty: Bool { term.isEmpty }
}

public enum CommitSearchError: LocalizedError, Equatable, Sendable {
    case invalidRegex(pattern: String)
    case invalidHashPrefix(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidRegex(pattern):
            "\"\(pattern)\" is not a valid regular expression. Check brackets and parentheses, or search plain text with Content (-S)."
        case let .invalidHashPrefix(text):
            "\"\(text)\" is not the start of a commit hash. Use only 0-9 and a-f."
        }
    }
}
