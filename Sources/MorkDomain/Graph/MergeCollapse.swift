import Foundation

public struct CollapsedHistory: Equatable, Sendable {
    public let rows: [GraphRow]
    public let hiddenBy: [String: String]
    public let hiddenCounts: [String: Int]

    public init(rows: [GraphRow], hiddenBy: [String: String] = [:], hiddenCounts: [String: Int] = [:]) {
        self.rows = rows
        self.hiddenBy = hiddenBy
        self.hiddenCounts = hiddenCounts
    }
}

public enum MergeCollapse {
    public static func mergedCommits(of merge: Commit, in commits: [Commit]) -> [Commit] {
        guard merge.isMerge, let start = commits.firstIndex(where: { $0.hash == merge.hash }) else { return [] }
        return merged(from: start, in: commits)
    }

    public static func collapse(_ history: [GraphRow], merges: Set<String>) -> CollapsedHistory {
        guard !merges.isEmpty else { return CollapsedHistory(rows: history) }
        let commits = history.map(\.commit)
        var claims: [String: [String]] = [:]
        for (index, commit) in commits.enumerated() where commit.isMerge && merges.contains(commit.hash) {
            for merged in merged(from: index, in: commits) {
                claims[merged.hash, default: []].append(commit.hash)
            }
        }
        guard !claims.isEmpty else { return CollapsedHistory(rows: history) }

        var children: [String: [String]] = [:]
        for commit in commits {
            for parent in commit.parents where claims[parent] != nil {
                children[parent, default: []].append(commit.hash)
            }
        }
        var hiddenBy: [String: String] = [:]
        var counts: [String: Int] = [:]
        for commit in commits {
            guard let owners = claims[commit.hash],
                  children[commit.hash, default: []].allSatisfy({ hiddenBy[$0] != nil || owners.contains($0) }) else { continue }
            var owner = owners.first { hiddenBy[$0] == nil } ?? owners[0]
            while let outer = hiddenBy[owner] { owner = outer }
            hiddenBy[commit.hash] = owner
            counts[owner, default: 0] += 1
        }
        guard !hiddenBy.isEmpty else { return CollapsedHistory(rows: history) }

        let hidden = Set(hiddenBy.keys)
        var lanes: [String?] = []
        let rows = CommitGraphLayout.layout(commits.filter { !hidden.contains($0.hash) }, lanes: &lanes, hiding: hidden)
        return CollapsedHistory(rows: rows, hiddenBy: hiddenBy, hiddenCounts: counts)
    }

    private static func merged(from start: Int, in commits: [Commit]) -> [Commit] {
        let merge = commits[start]
        guard let first = merge.parents.first else { return [] }
        var main: Set<String> = [first]
        var side = Set(merge.parents.dropFirst()).subtracting(main)
        var result: [Commit] = []
        var index = start + 1
        while !side.isEmpty, index < commits.count {
            let commit = commits[index]
            index += 1
            if main.remove(commit.hash) != nil {
                side.remove(commit.hash)
                main.formUnion(commit.parents)
            } else if side.remove(commit.hash) != nil {
                result.append(commit)
                side.formUnion(commit.parents)
            }
        }
        return result
    }
}
