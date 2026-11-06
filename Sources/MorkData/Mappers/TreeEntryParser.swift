import MorkDomain
import Foundation

enum TreeEntryParser {
    static func arguments(revision: String, directory: String) -> [String] {
        ["ls-tree", "-z", "-l", directory.isEmpty ? revision : "\(revision):\(directory)"]
    }

    static func parse(_ output: String, directory: String) -> [TreeEntry] {
        let prefix = directory.isEmpty ? "" : directory + "/"
        return output.split(separator: "\0", omittingEmptySubsequences: true).compactMap { record in
            guard let tab = record.firstIndex(of: "\t") else { return nil }
            let fields = record[..<tab].split(separator: " ", omittingEmptySubsequences: true)
            guard fields.count == 4 else { return nil }
            let name = record[record.index(after: tab)...]
            return TreeEntry(path: prefix + name, kind: kind(mode: fields[0], type: fields[1]), object: String(fields[2]), size: Int(fields[3]))
        }
    }

    private static func kind(mode: Substring, type: Substring) -> TreeEntry.Kind {
        switch (type, mode) {
        case ("tree", _): .directory
        case ("commit", _): .submodule
        case (_, "120000"): .symlink
        case (_, "100755"): .executable
        default: .file
        }
    }
}
