import Foundation

struct FilePathParts: Equatable {
    let directory: String
    let name: String

    init(_ path: String) {
        guard !path.hasSuffix("/"), let slash = path.lastIndex(of: "/") else {
            directory = ""
            name = path
            return
        }
        directory = String(path[...slash])
        name = String(path[path.index(after: slash)...])
    }

    var location: String {
        String(directory.dropLast())
    }

    var fileExtension: String {
        guard let dot = name.lastIndex(of: ".") else { return "" }
        return String(name[name.index(after: dot)...])
    }

    static func displayText(path: String, originalPath: String?) -> String {
        originalPath.map { "\($0) → \(path)" } ?? path
    }
}

struct StashLabel: Equatable {
    private static let prefixes = ["WIP on ", "On "]

    let title: String
    let branch: String?

    init(message: String) {
        for prefix in Self.prefixes where message.hasPrefix(prefix) {
            let rest = message.dropFirst(prefix.count)
            if let separator = rest.range(of: ": "), !rest[..<separator.lowerBound].isEmpty {
                title = String(rest[separator.upperBound...])
                branch = String(rest[..<separator.lowerBound])
                return
            }
        }
        title = message
        branch = nil
    }
}
