import Foundation

public enum BranchNameError: LocalizedError, Equatable, Sendable {
    case empty
    case invalid(String, reason: String)
    case exists(String)
    case conflicts(String, with: String)

    public var errorDescription: String? {
        switch self {
        case .empty:
            "Enter a branch name."
        case let .invalid(name, reason):
            "\"\(name)\" is not a valid branch name: \(reason)."
        case let .exists(name):
            "A branch named \"\(name)\" already exists."
        case let .conflicts(name, other):
            "\"\(name)\" cannot exist next to the branch \"\(other)\": git stores branches as files, so one name cannot also be a folder of the other."
        }
    }
}

public enum BranchNameRules {
    private static let forbiddenCharacters: Set<Character> = ["~", "^", ":", "?", "*", "[", "\\"]

    public static func validate(_ name: String, existing: [String]) throws {
        if let problem = problem(with: name, existing: existing) { throw problem }
    }

    public static func problem(with name: String, existing: [String]) -> BranchNameError? {
        guard !name.isEmpty else { return .empty }
        if let reason = reason(against: name) { return .invalid(name, reason: reason) }
        if existing.contains(name) { return .exists(name) }
        if let other = existing.first(where: { name.hasPrefix($0 + "/") || $0.hasPrefix(name + "/") }) {
            return .conflicts(name, with: other)
        }
        return nil
    }

    private static func reason(against name: String) -> String? {
        if name.unicodeScalars.contains(where: { $0.properties.isWhitespace || $0.value < 0x20 || $0.value == 0x7f }) {
            return "it cannot contain spaces or control characters"
        }
        if name.contains(where: forbiddenCharacters.contains) {
            return "it cannot contain ~ ^ : ? * [ or \\"
        }
        if name.hasPrefix("-") {
            return "it cannot start with -, git would read it as an option"
        }
        if name == "@" || name == "HEAD" {
            return "\(name) is reserved by git"
        }
        if name.contains("..") {
            return "it cannot contain .."
        }
        if name.contains("@{") {
            return "it cannot contain @{"
        }
        if name.hasPrefix("/") || name.hasSuffix("/") || name.contains("//") {
            return "it cannot start or end with / or contain //"
        }
        if name.hasSuffix(".") {
            return "it cannot end with ."
        }
        if name.split(separator: "/").contains(where: { $0.hasPrefix(".") || $0.hasSuffix(".lock") }) {
            return "no part between slashes can start with . or end with .lock"
        }
        return nil
    }
}
