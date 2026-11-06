import MorkDomain
import Foundation

enum BranchOutline {
    static let folderPrefix = "folder:"
    static let collapseThreshold = 300

    struct Row: Identifiable, Equatable {
        let node: BranchNode
        let depth: Int

        var id: String { node.id }
    }

    static func rows(_ nodes: [BranchNode], collapsed: Set<String>, expandAll: Bool) -> [Row] {
        var rows: [Row] = []
        append(nodes, depth: 0, collapsed: collapsed, expandAll: expandAll, to: &rows)
        return rows
    }

    static func folderIDs(containing branchName: String) -> [String] {
        let components = branchName.split(separator: "/").map(String.init)
        guard components.count > 1 else { return [] }
        return (1..<components.count).map { folderPrefix + components.prefix($0).joined(separator: "/") }
    }

    static func folderIDs(in nodes: [BranchNode]) -> Set<String> {
        var ids: Set<String> = []
        var pending = nodes.filter { $0.branch == nil }
        while let node = pending.popLast() {
            ids.insert(node.id)
            pending += node.children.filter { $0.branch == nil }
        }
        return ids
    }

    static func collapsed(toggled: Set<String>, tree: [BranchNode], collapsesByDefault: Bool, keepingOpen open: [String] = []) -> Set<String> {
        guard collapsesByDefault else { return toggled }
        return folderIDs(in: tree).subtracting(open).symmetricDifference(toggled)
    }

    static func path(ofFolder id: String) -> String {
        id.hasPrefix(folderPrefix) ? String(id.dropFirst(folderPrefix.count)) : id
    }

    private static func append(_ nodes: [BranchNode], depth: Int, collapsed: Set<String>, expandAll: Bool, to rows: inout [Row]) {
        for node in nodes {
            rows.append(Row(node: node, depth: depth))
            if node.branch == nil, expandAll || !collapsed.contains(node.id) {
                append(node.children, depth: depth + 1, collapsed: collapsed, expandAll: expandAll, to: &rows)
            }
        }
    }
}

extension Branch {
    var trackSummary: String? {
        let parts = [ahead > 0 ? "\(ahead)↑" : nil, behind > 0 ? "\(behind)↓" : nil].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}
