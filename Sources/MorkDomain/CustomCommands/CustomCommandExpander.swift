import Foundation

public enum CustomCommandExpander {
    public static func expand(_ command: CustomCommand, in context: CustomCommandContext) throws -> CustomCommandInvocation {
        for variable in command.variables where context.value(of: variable) == nil {
            throw CustomCommandError.missingValue(variable, command: command.name)
        }
        switch command.kind {
        case .git:
            var words = ShellWords.split(command.commandLine)
            if words.first == "git" { words.removeFirst() }
            guard !words.isEmpty else { throw CustomCommandError.emptyCommand(command.name) }
            return .git(words.map { literal($0, context: context) })
        case .shell:
            let script = command.commandLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !script.isEmpty else { throw CustomCommandError.emptyCommand(command.name) }
            return .shell(shellEscaped(script, context: context))
        }
    }

    private enum Quote {
        case none
        case single
        case double
    }

    static func shellEscaped(_ script: String, context: CustomCommandContext) -> String {
        substitute(in: script, context: context) { value, quote in
            switch quote {
            case .none: ShellWords.quote(value)
            case .single: value.replacingOccurrences(of: "'", with: "'\\''")
            case .double: escapeForDoubleQuotes(value)
            }
        }
    }

    static func literal(_ word: String, context: CustomCommandContext) -> String {
        let characters = Array(word)
        var result = ""
        var index = 0
        while index < characters.count {
            if characters[index] == "$", let (variable, end) = variable(at: index, in: characters), let value = context.value(of: variable) {
                result += value
                index = end
            } else {
                result.append(characters[index])
                index += 1
            }
        }
        return result
    }

    private static func escapeForDoubleQuotes(_ value: String) -> String {
        var result = ""
        for character in value {
            if character == "\\" || character == "\"" || character == "$" || character == "`" { result.append("\\") }
            result.append(character)
        }
        return result
    }

    private static func substitute(in text: String, context: CustomCommandContext, escape: (String, Quote) -> String) -> String {
        let characters = Array(text)
        var result = ""
        var quote = Quote.none
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if character == "$", let (variable, end) = variable(at: index, in: characters), let value = context.value(of: variable) {
                result += escape(value, quote)
                index = end
                continue
            }
            result.append(character)
            switch (quote, character) {
            case (.none, "\\"), (.double, "\\"):
                if index + 1 < characters.count {
                    result.append(characters[index + 1])
                    index += 1
                }
            case (.none, "'"): quote = .single
            case (.none, "\""): quote = .double
            case (.single, "'"), (.double, "\""): quote = .none
            default: break
            }
            index += 1
        }
        return result
    }

    private static func variable(at index: Int, in characters: [Character]) -> (CustomCommandVariable, Int)? {
        guard index + 1 < characters.count, characters[index + 1] == "{",
              let close = characters[(index + 2)...].firstIndex(of: "}")
        else { return nil }
        guard let variable = CustomCommandVariable(rawValue: String(characters[(index + 2)..<close])) else { return nil }
        return (variable, close + 1)
    }
}
