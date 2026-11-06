import MorkDomain
import Foundation

enum BranchSidebarSorting {
    static func sorted(_ nodes: [BranchNode], order: BranchSortOrder, recent: [String]) -> [BranchNode] {
        let ranks = Dictionary(recent.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: min)
        return sorted(nodes, order: order, ranks: ranks).map(\.node)
    }

    private static func sorted(_ nodes: [BranchNode], order: BranchSortOrder, ranks: [String: Int]) -> [(node: BranchNode, rank: Int)] {
        let prioritized = order == .alphabeticalMainAndFoldersFirst || order == .alphabeticalDescendingMainAndFoldersFirst
        let descending = order == .alphabeticalDescending || order == .alphabeticalDescendingMainAndFoldersFirst
        func priority(_ node: BranchNode) -> Int {
            if node.branch?.localName == "master" { return 0 }
            if node.branch?.localName == "main" { return 1 }
            return node.branch == nil ? 2 : 3
        }
        return nodes.map { node in
            let children = sorted(node.children, order: order, ranks: ranks)
            let rank = node.branch.flatMap { ranks[$0.fullName] } ?? children.map(\.rank).min() ?? Int.max
            return (node: BranchNode(id: node.id, name: node.name, branch: node.branch, children: children.map(\.node)), rank: rank)
        }.sorted { left, right in
            if order == .recentlyUsed, left.rank != right.rank { return left.rank < right.rank }
            if prioritized, priority(left.node) != priority(right.node) { return priority(left.node) < priority(right.node) }
            let comparison = left.node.name.localizedStandardCompare(right.node.name)
            if comparison == .orderedSame { return left.node.id < right.node.id }
            return descending ? comparison == .orderedDescending : comparison == .orderedAscending
        }
    }
}
