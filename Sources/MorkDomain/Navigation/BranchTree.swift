import Foundation

public struct BranchNode: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let branch: Branch?
    public let children: [BranchNode]

    public init(id: String, name: String, branch: Branch?, children: [BranchNode]) {
        self.id = id
        self.name = name
        self.branch = branch
        self.children = children
    }
}

public enum BranchTree {
    public static func build(_ branches: [Branch], filter: String = "") -> [BranchNode] {
        let query = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        let visible = query.isEmpty ? branches : branches.filter { $0.name.localizedCaseInsensitiveContains(query) }
        let entries = visible.map { branch in
            (components: branch.name.split(separator: "/").map(String.init), branch: branch)
        }
        return nodes(for: entries, prefix: [])
    }

    private static func nodes(for entries: [(components: [String], branch: Branch)], prefix: [String]) -> [BranchNode] {
        var leaves: [BranchNode] = []
        var groups: [String: [(components: [String], branch: Branch)]] = [:]
        for entry in entries {
            guard let head = entry.components.first else { continue }
            if entry.components.count == 1 {
                leaves.append(BranchNode(id: entry.branch.fullName, name: head, branch: entry.branch, children: []))
            } else {
                groups[head, default: []].append((Array(entry.components.dropFirst()), entry.branch))
            }
        }
        let folders = groups.map { name, members in
            let path = prefix + [name]
            return BranchNode(
                id: "folder:" + path.joined(separator: "/"),
                name: name,
                branch: nil,
                children: nodes(for: members, prefix: path)
            )
        }
        return sorted(leaves) + sorted(folders)
    }

    private static func sorted(_ nodes: [BranchNode]) -> [BranchNode] {
        nodes.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
