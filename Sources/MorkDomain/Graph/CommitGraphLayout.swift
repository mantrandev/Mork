import Foundation

public struct GraphEdge: Hashable, Sendable {
    public enum Half: Hashable, Sendable {
        case top
        case bottom
    }

    public let half: Half
    public let from: Int
    public let to: Int

    public init(half: Half, from: Int, to: Int) {
        self.half = half
        self.from = from
        self.to = to
    }
}

public struct GraphRow: Identifiable, Hashable, Sendable {
    public let commit: Commit
    public let column: Int
    public let width: Int
    public let edges: [GraphEdge]

    public init(commit: Commit, column: Int, width: Int, edges: [GraphEdge]) {
        self.commit = commit
        self.column = column
        self.width = width
        self.edges = edges
    }

    public var id: String { commit.hash }
}

public struct HistoryCursor: Hashable, Sendable {
    public var lanes: [String?]
    public var loadedCommits: Int
    public var isComplete: Bool

    public init(lanes: [String?] = [], loadedCommits: Int = 0, isComplete: Bool = false) {
        self.lanes = lanes
        self.loadedCommits = loadedCommits
        self.isComplete = isComplete
    }

    public static let start = HistoryCursor()

    public func advanced(over commits: [Commit], lanes: [String?], limit: Int) -> HistoryCursor {
        let consumed = commits.count { !$0.refNames.contains(where: StashHistory.isStashRef) }
        return HistoryCursor(lanes: lanes, loadedCommits: loadedCommits + consumed, isComplete: consumed < limit)
    }
}

public enum CommitGraphLayout {
    public static func layout(_ commits: [Commit]) -> [GraphRow] {
        var lanes: [String?] = []
        return layout(commits, lanes: &lanes)
    }

    public static func layout(_ commits: [Commit], lanes: inout [String?]) -> [GraphRow] {
        var rows: [GraphRow] = []
        rows.reserveCapacity(commits.count)

        for commit in commits {
            let before = lanes
            let column = lanes.firstIndex(of: commit.hash) ?? open(commit.hash, in: &lanes)
            var edges = before.indices.compactMap { index -> GraphEdge? in
                guard let hash = before[index] else { return nil }
                return GraphEdge(half: .top, from: index, to: hash == commit.hash ? column : index)
            }

            for index in lanes.indices where lanes[index] == commit.hash {
                lanes[index] = nil
            }
            var targets = Set<Int>()
            if let first = commit.parents.first {
                lanes[column] = first
                targets.insert(column)
            }
            for parent in commit.parents.dropFirst() {
                targets.insert(lanes.firstIndex(of: parent) ?? open(parent, in: &lanes))
            }
            while lanes.last == .some(nil) {
                lanes.removeLast()
            }

            for index in lanes.indices where lanes[index] != nil {
                if index < before.count, let passing = before[index], passing != commit.hash, lanes[index] == passing {
                    edges.append(GraphEdge(half: .bottom, from: index, to: index))
                }
                if targets.contains(index) {
                    edges.append(GraphEdge(half: .bottom, from: column, to: index))
                }
            }

            let width = max(before.count, lanes.count, column + 1)
            rows.append(GraphRow(commit: commit, column: column, width: width, edges: edges))
        }
        return rows
    }

    private static func open(_ hash: String, in lanes: inout [String?]) -> Int {
        if let free = lanes.firstIndex(of: nil) {
            lanes[free] = hash
            return free
        }
        lanes.append(hash)
        return lanes.count - 1
    }
}
