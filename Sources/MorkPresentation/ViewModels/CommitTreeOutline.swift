import MorkDomain
import Foundation

public struct TreeRow: Identifiable, Equatable, Sendable {
    public enum Content: Equatable, Sendable {
        case entry(TreeEntry)
        case loading
        case failed(String)
        case empty
    }

    public let id: String
    public let depth: Int
    public let content: Content
    public let isExpanded: Bool
    public var sizeText: String?

    public var entry: TreeEntry? {
        if case let .entry(entry) = content { entry } else { nil }
    }
}

public enum CommitTreeOutline {
    public static func filtered(_ rows: [TreeRow], by filter: String) -> [TreeRow] {
        let query = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return rows }
        let matches = rows.compactMap { row in row.entry.flatMap { $0.name.localizedCaseInsensitiveContains(query) ? row.id : nil } }
        var kept = Set(matches)
        for path in matches {
            var parent = path
            while let slash = parent.lastIndex(of: "/") {
                parent = String(parent[..<slash])
                kept.insert(parent)
            }
        }
        return rows.filter { $0.entry != nil && kept.contains($0.id) }
    }

    public static func rows(root: [TreeEntry], children: [String: Loadable<[TreeEntry]>], expanded: Set<String>, sizes: [String: String] = [:]) -> [TreeRow] {
        var rows: [TreeRow] = []
        append(root, depth: 0, children: children, expanded: expanded, sizes: sizes, to: &rows)
        return rows
    }

    public static func sizeTexts(_ entries: [TreeEntry]) -> [String: String] {
        var texts: [String: String] = [:]
        for entry in entries where !entry.isDirectory {
            guard let size = entry.size else { continue }
            texts[entry.path] = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        }
        return texts
    }

    private static func append(_ entries: [TreeEntry], depth: Int, children: [String: Loadable<[TreeEntry]>], expanded: Set<String>, sizes: [String: String], to rows: inout [TreeRow]) {
        for entry in entries {
            let isOpen = entry.isDirectory && expanded.contains(entry.path)
            rows.append(TreeRow(id: entry.path, depth: depth, content: .entry(entry), isExpanded: isOpen, sizeText: sizes[entry.path]))
            guard isOpen else { continue }
            switch children[entry.path] ?? .loading {
            case .idle, .loading:
                rows.append(TreeRow(id: "\u{0}loading:\(entry.path)", depth: depth + 1, content: .loading, isExpanded: false))
            case let .failed(message):
                rows.append(TreeRow(id: "\u{0}failed:\(entry.path)", depth: depth + 1, content: .failed(message), isExpanded: false))
            case let .loaded(nested) where nested.isEmpty:
                rows.append(TreeRow(id: "\u{0}empty:\(entry.path)", depth: depth + 1, content: .empty, isExpanded: false))
            case let .loaded(nested):
                append(nested, depth: depth + 1, children: children, expanded: expanded, sizes: sizes, to: &rows)
            }
        }
    }
}
