import Foundation

public struct CommitMessage: Equatable, Sendable {
    public static let recommendedSubjectLength = 72

    public let subject: String
    public let description: String

    public init(subject: String, description: String) {
        self.subject = subject
        self.description = description
    }

    public init(parsing message: String) {
        let trimmed = message.trimmingCharacters(in: .newlines)
        let lines = trimmed.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        subject = lines.first.map(String.init) ?? ""
        description = lines.count > 1 ? String(lines[1]).trimmingCharacters(in: .newlines) : ""
    }

    public var text: String {
        let subject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if subject.isEmpty { return description }
        if description.isEmpty { return subject }
        return subject + "\n\n" + description
    }

    public var isEmpty: Bool { text.isEmpty }
    public var isSubjectTooLong: Bool { subject.count > Self.recommendedSubjectLength }
}
