import Foundation

public struct LessonNote: Identifiable, Hashable, Sendable {
    public let name: String
    public let text: String

    public init(name: String, text: String) {
        self.name = name
        self.text = text
    }

    public var id: String { name }
}

public struct LessonTopic: Identifiable, Hashable, Sendable {
    public let command: String
    public let summary: String
    public let explanation: String
    public let actions: [LessonNote]
    public let flags: [LessonNote]

    public init(command: String, summary: String, explanation: String, actions: [LessonNote], flags: [LessonNote]) {
        self.command = command
        self.summary = summary
        self.explanation = explanation
        self.actions = actions
        self.flags = flags
    }

    public var id: String { command }
}

public struct LessonCatalog: Sendable {
    public static let standard = LessonCatalog(topics: Lessons.catalogTopics())
    public static let coreCommands = ["commit", "branch", "merge", "push"]

    public let topics: [LessonTopic]
    private let index: [String: LessonTopic]

    public init(topics: [LessonTopic]) {
        self.topics = topics
        index = Dictionary(topics.map { ($0.command, $0) }) { first, _ in first }
    }

    public var coreTopics: [LessonTopic] {
        Self.coreCommands.compactMap { index[$0] }
    }

    public func topic(_ command: String) -> LessonTopic? {
        index[command]
    }

    public func search(_ query: String) -> [LessonTopic] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return topics }
        let ranked = topics.enumerated().compactMap { offset, topic in
            Self.rank(of: topic, for: needle).map { (rank: $0, offset: offset, topic: topic) }
        }
        return ranked.sorted { ($0.rank, $0.offset) < ($1.rank, $1.offset) }.map(\.topic)
    }

    static func summary(of explanation: String) -> String {
        var previous: Character?
        for index in explanation.indices {
            let character = explanation[index]
            if previous == ".", character.isWhitespace {
                return String(explanation[..<index])
            }
            previous = character
        }
        return explanation
    }

    private static func rank(of topic: LessonTopic, for needle: String) -> Int? {
        if topic.command == needle { return 0 }
        if topic.command.hasPrefix(needle) { return 1 }
        if topic.command.contains(needle) { return 2 }
        let notes = topic.flags + topic.actions
        if topic.summary.lowercased().contains(needle) || notes.contains(where: { $0.name.lowercased().contains(needle) }) { return 3 }
        return nil
    }
}

extension Lessons {
    static func catalogTopics() -> [LessonTopic] {
        let explanations = commands.merging(advancedCommands) { first, _ in first }
            .merging(commitActionCommands) { first, _ in first }
        return explanations.keys.sorted().map { command in
            let explanation = explanations[command] ?? ""
            return LessonTopic(
                command: command,
                summary: LessonCatalog.summary(of: explanation),
                explanation: explanation,
                actions: notes([actions, advancedActions], for: command),
                flags: notes([subcommandFlags, advancedFlags, commitActionFlags, branchMenuFlags], for: command)
            )
        }
    }

    private static func notes(_ tables: [[String: [String: String]]], for command: String) -> [LessonNote] {
        let merged = tables.reduce(into: [String: String]()) { result, table in
            result.merge(table[command] ?? [:]) { first, _ in first }
        }
        return merged.keys.sorted().map { LessonNote(name: $0, text: merged[$0] ?? "") }
    }
}
