import Foundation

private let folderPrefix = "\u{0}folder:"

public enum FileListMode: String, CaseIterable, Sendable {
    case flat
    case tree

    public var title: String {
        switch self {
        case .flat: "Show as List"
        case .tree: "Show as Tree"
        }
    }

    public var systemImage: String {
        switch self {
        case .flat: "list.bullet"
        case .tree: "list.bullet.indent"
        }
    }
}

public struct FileListRow<File: Hashable & Sendable>: Identifiable, Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case folder
        case file(File)
    }

    public let id: String
    public let kind: Kind
    public let title: String
    public let depth: Int
    public var isExpanded = false

    public var file: File? {
        if case let .file(file) = kind { return file }
        return nil
    }

    public var folderPath: String? {
        if case .folder = kind { return FileList.folderPath(ofID: id) }
        return nil
    }
}

enum FileList {
    static func folderID(_ path: String) -> String {
        folderPrefix + path
    }

    static func folderPath(ofID id: String) -> String? {
        id.hasPrefix(folderPrefix) ? String(id.dropFirst(folderPrefix.count)) : nil
    }

    static func files<File>(_ files: [File], matching ids: Set<String>, path: (File) -> String) -> [File] {
        let folders = ids.compactMap(folderPath(ofID:)).map { $0 + "/" }
        return files.filter { file in
            let filePath = path(file)
            return ids.contains(filePath) || folders.contains { filePath.hasPrefix($0) }
        }
    }

    static func reconcile<File>(_ ids: Set<String>, to rows: [FileListRow<File>]) -> Set<String> {
        guard !ids.isEmpty else { return ids }
        let present = Set(rows.map(\.id))
        var kept = ids.intersection(present)
        for id in ids.subtracting(present) {
            guard let folder = folderPath(ofID: id), let row = rows.first(where: { merges($0, folder) }) else { continue }
            kept.insert(row.id)
        }
        return kept
    }

    private static func merges<File>(_ row: FileListRow<File>, _ folder: String) -> Bool {
        guard let path = row.folderPath, path.hasPrefix(folder + "/") else { return false }
        let start = path.split(separator: "/").count - row.title.split(separator: "/").count
        return folder.split(separator: "/").count > start
    }

    static func rows<File>(_ files: [File], mode: FileListMode, collapsed: Set<String> = [], path: (File) -> String) -> [FileListRow<File>] {
        switch mode {
        case .flat:
            return files.map { file in
                let filePath = path(file)
                return FileListRow(id: filePath, kind: .file(file), title: filePath, depth: 0)
            }
        case .tree:
            let root = Folder<File>()
            var byDirectory: [Substring: Folder<File>] = [:]
            for file in files {
                let filePath = path(file)
                let slash = filePath.dropLast(filePath.hasSuffix("/") ? 1 : 0).lastIndex(of: "/")
                let directory = slash.map { filePath[..<$0] } ?? ""
                let name = slash.map { String(filePath[filePath.index(after: $0)...]) } ?? filePath
                let folder = byDirectory[directory] ?? directory.split(separator: "/").reduce(root) { $0.child(String($1)) }
                byDirectory[directory] = folder
                folder.files.append((name: name, file: file, path: filePath))
            }
            var rows: [FileListRow<File>] = []
            root.append(to: &rows, path: "", depth: 0, collapsed: collapsed)
            return rows
        }
    }

    private final class Folder<File: Hashable & Sendable> {
        var folders: [String: Folder] = [:]
        var files: [(name: String, file: File, path: String)] = []

        func child(_ name: String) -> Folder {
            if let existing = folders[name] { return existing }
            let folder = Folder()
            folders[name] = folder
            return folder
        }

        func append(to rows: inout [FileListRow<File>], path: String, depth: Int, collapsed: Set<String>) {
            for (name, child) in folders.sorted(by: { $0.key.localizedStandardCompare($1.key) == .orderedAscending }) {
                var title = name
                var full = path.isEmpty ? name : path + "/" + name
                var folder = child
                while !collapsed.contains(full), folder.files.isEmpty, folder.folders.count == 1, let only = folder.folders.first {
                    title += "/" + only.key
                    full += "/" + only.key
                    folder = only.value
                }
                let isExpanded = !collapsed.contains(full)
                rows.append(FileListRow(id: FileList.folderID(full), kind: .folder, title: title, depth: depth, isExpanded: isExpanded))
                if isExpanded { folder.append(to: &rows, path: full, depth: depth + 1, collapsed: collapsed) }
            }
            for entry in files.sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) {
                rows.append(FileListRow(id: entry.path, kind: .file(entry.file), title: entry.name, depth: depth))
            }
        }
    }
}
