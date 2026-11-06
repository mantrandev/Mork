import Foundation

public enum SubmoduleStatusParser {
    private struct Module {
        var name: String
        var path: String?
        var url: String?
    }

    public static func parse(status: String, modules: String) -> [Submodule] {
        let byPath = modulesByPath(modules)
        let entries = status.split(whereSeparator: \.isNewline).compactMap { entry(String($0)) }
        let paths = entries.map(\.path)
        return entries.map { entry in
            let module = byPath[entry.path]
            return Submodule(
                name: module?.name ?? entry.path,
                path: entry.path,
                url: module?.url,
                commit: entry.commit,
                state: entry.state,
                describe: entry.describe,
                isNested: module == nil && paths.contains { entry.path.hasPrefix($0 + "/") }
            )
        }
    }

    private static func entry(_ line: String) -> (path: String, commit: String, state: Submodule.State, describe: String?)? {
        let line = line.hasSuffix("\r") ? String(line.dropLast()) : line
        guard let marker = line.first, let state = submoduleState(for: marker) else { return nil }
        let rest = line.dropFirst()
        guard let space = rest.firstIndex(of: " ") else { return nil }
        let commit = String(rest[..<space])
        guard commit.count >= 40, commit.allSatisfy(\.isHexDigit) else { return nil }
        var path = String(rest[rest.index(after: space)...])
        var describe: String?
        if state == .current || state == .outOfSync, path.hasSuffix(")"), let open = path.range(of: " (", options: .backwards) {
            describe = String(path[open.upperBound..<path.index(before: path.endIndex)])
            path = String(path[..<open.lowerBound])
        }
        guard !path.isEmpty else { return nil }
        return (path, commit, state, describe)
    }

    private static func submoduleState(for marker: Character) -> Submodule.State? {
        switch marker {
        case " ": .current
        case "-": .notInitialized
        case "+": .outOfSync
        case "U": .conflict
        default: nil
        }
    }

    private static func modulesByPath(_ output: String) -> [String: Module] {
        var modules: [String: Module] = [:]
        for record in output.split(separator: "\0") {
            guard let newline = record.firstIndex(of: "\n") else { continue }
            let key = record[..<newline]
            var value = String(record[record.index(after: newline)...])
            if value.hasSuffix("\r") { value.removeLast() }
            guard key.hasPrefix("submodule."), let dot = key.lastIndex(of: "."), dot > key.index(key.startIndex, offsetBy: 9) else { continue }
            let name = String(key[key.index(key.startIndex, offsetBy: 10)..<dot])
            var module = modules[name] ?? Module(name: name)
            switch key[key.index(after: dot)...] {
            case "path": module.path = value
            case "url": module.url = value
            default: break
            }
            modules[name] = module
        }
        return Dictionary(modules.values.compactMap { module in module.path.map { ($0, module) } }) { first, _ in first }
    }
}
