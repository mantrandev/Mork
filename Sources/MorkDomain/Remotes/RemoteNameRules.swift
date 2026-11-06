import Foundation

public enum RemoteNameRules {
    private static let forbiddenCharacters: Set<Character> = ["~", "^", ":", "?", "*", "[", "\\"]

    public static func validate(_ name: String, existing: [String]) throws {
        if let problem = problem(with: name, existing: existing) { throw problem }
    }

    public static func problem(with name: String, existing: [String]) -> RemoteValidationError? {
        guard !name.isEmpty else { return .emptyName }
        if let reason = reason(against: name) { return .invalidName(name, reason: reason) }
        if existing.contains(name) { return .duplicateName(name) }
        return nil
    }

    private static func reason(against name: String) -> String? {
        if name.unicodeScalars.contains(where: { $0.properties.isWhitespace || $0.value < 0x20 || $0.value == 0x7f }) {
            return "it cannot contain spaces or control characters"
        }
        if name.contains(where: forbiddenCharacters.contains) {
            return "it cannot contain ~ ^ : ? * [ or \\"
        }
        if name.contains("/") {
            return "Mork does not allow / in remote names, because remote branches are grouped by the part before the first /"
        }
        if name.hasPrefix("-") {
            return "it cannot start with -, git would read it as an option"
        }
        if name.hasPrefix(".") {
            return "it cannot start with ."
        }
        if name.contains("..") {
            return "it cannot contain .."
        }
        if name.contains("@{") {
            return "it cannot contain @{"
        }
        if name.hasSuffix(".lock") {
            return "it cannot end with .lock"
        }
        return nil
    }
}
