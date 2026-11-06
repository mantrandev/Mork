import MorkDomain
import Foundation

struct TagSidebarRow: Identifiable, Equatable {
    let id: String
    let title: String
    let depth: Int
    let tag: Tag?
    var isExpanded = false
}

enum TagSidebarRows {
    private final class Node {
        var children: [String: Node] = [:]
        var tag: Tag?
    }

    static func make(tags: [Tag], order: TagSortOrder, collapsed: Set<String>) -> [TagSidebarRow] {
        if order == .recentlyUsed {
            return tags.sorted { left, right in
                switch (left.createdAt, right.createdAt) {
                case let (leftDate?, rightDate?) where leftDate != rightDate: return leftDate > rightDate
                case (_?, nil): return true
                case (nil, _?): return false
                default:
                    let comparison = left.name.localizedStandardCompare(right.name)
                    return comparison == .orderedSame ? left.name < right.name : comparison == .orderedAscending
                }
            }.map {
                TagSidebarRow(id: "tag:\($0.name)", title: $0.name, depth: 0, tag: $0)
            }
        }
        let root = Node()
        for tag in tags {
            var node = root
            for component in tag.name.split(separator: "/").map(String.init) {
                let child = node.children[component] ?? Node()
                node.children[component] = child
                node = child
            }
            node.tag = tag
        }
        var rows: [TagSidebarRow] = []
        append(root, path: "", depth: 0, order: order, collapsed: collapsed, to: &rows)
        return rows
    }

    private static func append(_ node: Node, path: String, depth: Int, order: TagSortOrder, collapsed: Set<String>, to rows: inout [TagSidebarRow]) {
        let foldersFirst = order == .alphabeticalFoldersFirst || order == .alphabeticalDescendingFoldersFirst
        let descending = order == .alphabeticalDescending || order == .alphabeticalDescendingFoldersFirst
        let names = node.children.keys.sorted { left, right in
            if foldersFirst {
                let leftFolder = node.children[left]?.tag == nil
                let rightFolder = node.children[right]?.tag == nil
                if leftFolder != rightFolder { return leftFolder }
            }
            let comparison = left.localizedStandardCompare(right)
            if comparison == .orderedSame { return descending ? left > right : left < right }
            return descending ? comparison == .orderedDescending : comparison == .orderedAscending
        }
        for name in names {
            guard let child = node.children[name] else { continue }
            let childPath = path.isEmpty ? name : "\(path)/\(name)"
            if let tag = child.tag {
                rows.append(TagSidebarRow(id: "tag:\(tag.name)", title: name, depth: depth, tag: tag))
            } else {
                let expanded = !collapsed.contains(childPath)
                rows.append(TagSidebarRow(id: "folder:\(childPath)", title: name, depth: depth, tag: nil, isExpanded: expanded))
                if expanded { append(child, path: childPath, depth: depth + 1, order: order, collapsed: collapsed, to: &rows) }
            }
        }
    }
}
