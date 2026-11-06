import Foundation

public enum ShellWords {
    private static let safeCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_./=:@%^,+"))
    private static let doubleQuoteEscapable: Set<Character> = ["\"", "\\", "$", "`"]

    public static func split(_ input: String) -> [String] {
        var words: [String] = []
        var current = ""
        var quote: Character?
        var hasWord = false
        var escaping = false

        for character in input {
            if escaping {
                if quote == "\"" && !doubleQuoteEscapable.contains(character) { current.append("\\") }
                current.append(character)
                escaping = false
            } else if character == "\\" && quote != "'" {
                escaping = true
                hasWord = true
            } else if let active = quote {
                if character == active { quote = nil } else { current.append(character) }
            } else if character == "'" || character == "\"" {
                quote = character
                hasWord = true
            } else if character.isWhitespace {
                if hasWord { words.append(current) }
                current = ""
                hasWord = false
            } else {
                current.append(character)
                hasWord = true
            }
        }
        if hasWord { words.append(current) }
        return words
    }

    public static func quote(_ word: String) -> String {
        if !word.isEmpty, word.unicodeScalars.allSatisfy(safeCharacters.contains) { return word }
        return "'" + word.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
