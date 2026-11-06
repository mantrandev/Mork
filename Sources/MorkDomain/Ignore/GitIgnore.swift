import Foundation

public enum IgnoreTarget: String, CaseIterable, Identifiable, Sendable {
    case gitignore
    case exclude

    public var id: String { rawValue }

    public var fileName: String {
        switch self {
        case .gitignore: ".gitignore"
        case .exclude: ".git/info/exclude"
        }
    }

    public var lesson: String {
        switch self {
        case .gitignore:
            ".gitignore lives in the repository and is committed, so everyone who clones it ignores the same files. A leading / anchors a rule to the repository root, a trailing / matches only folders, * matches any characters except /."
        case .exclude:
            ".git/info/exclude uses the same rules as .gitignore but lives inside .git, so it is never committed. Use it for files only you create, like editor or OS files. Linked worktrees share it with the main repository."
        }
    }
}

public struct IgnoreSuggestion: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case file
        case fileExtension
        case folder
    }

    public let kind: Kind
    public let pattern: String

    public init(kind: Kind, pattern: String) {
        self.kind = kind
        self.pattern = pattern
    }
}

public enum GitIgnorePattern {
    private static let globCharacters: Set<Character> = ["\\", "*", "?", "["]

    public static func escape(_ literal: String) -> String? {
        guard !literal.isEmpty, !literal.contains(where: { $0 == "\n" || $0 == "\r" }) else { return nil }
        var escaped = ""
        for character in literal {
            if globCharacters.contains(character) { escaped.append("\\") }
            escaped.append(character)
        }
        if let first = escaped.first, first == "#" || first == "!" { escaped.insert("\\", at: escaped.startIndex) }
        let trailing = escaped.reversed().prefix { $0 == " " }.count
        if trailing > 0 {
            escaped = String(escaped.dropLast(trailing)) + String(repeating: "\\ ", count: trailing)
        }
        return escaped
    }

    public static func suggestions(for path: String) -> [IgnoreSuggestion] {
        guard let file = anchored(path) else { return [] }
        var suggestions = [IgnoreSuggestion(kind: .file, pattern: file)]
        let name = path.split(separator: "/").last.map(String.init) ?? path
        if let dot = name.lastIndex(of: "."), dot != name.startIndex, let fileExtension = escape(String(name[name.index(after: dot)...])) {
            suggestions.append(IgnoreSuggestion(kind: .fileExtension, pattern: "*." + fileExtension))
        }
        if let slash = path.lastIndex(of: "/"), let folder = anchored(String(path[..<slash])) {
            suggestions.append(IgnoreSuggestion(kind: .folder, pattern: folder + "/"))
        }
        return suggestions
    }

    public static func custom(_ input: String) -> String? {
        let pattern = input.trimmingCharacters(in: .newlines)
        guard !pattern.contains(where: { $0 == "\n" || $0 == "\r" }), !pattern.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return pattern
    }

    private static func anchored(_ path: String) -> String? {
        guard let escaped = escape(path) else { return nil }
        return "/" + (escaped.hasPrefix("\\#") || escaped.hasPrefix("\\!") ? String(escaped.dropFirst()) : escaped)
    }
}

public enum GitIgnoreFile {
    public static func appending(_ rule: String, to contents: String) -> String? {
        let lines = contents.unicodeScalars.split(separator: "\n", omittingEmptySubsequences: false)
        guard !lines.contains(where: { String($0.last == "\r" ? $0.dropLast() : $0) == rule }) else { return nil }
        let separator = contents.isEmpty || contents.unicodeScalars.last == "\n" ? "" : "\n"
        return contents + separator + rule + "\n"
    }
}

public struct IgnoreMatch: Hashable, Sendable {
    public let source: String
    public let line: Int
    public let pattern: String

    public init(source: String, line: Int, pattern: String) {
        self.source = source
        self.line = line
        self.pattern = pattern
    }
}

public struct IgnoreRuleResult: Hashable, Sendable {
    public let rule: String
    public let target: IgnoreTarget
    public let added: Bool
    public let match: IgnoreMatch?

    public init(rule: String, target: IgnoreTarget, added: Bool, match: IgnoreMatch?) {
        self.rule = rule
        self.target = target
        self.added = added
        self.match = match
    }

    public var ignoresPath: Bool {
        guard let match else { return false }
        return !match.pattern.hasPrefix("!")
    }
}
