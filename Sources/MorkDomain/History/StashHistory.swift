import Foundation

public enum StashHistory {
    private static let selectorPrefix = "stash@{"
    private static let stashRef = "refs/stash"

    public static func isStashRef(_ ref: String) -> Bool {
        ref == stashRef || ref.hasPrefix(selectorPrefix)
    }

    public static func merge(_ stashes: [Commit], into commits: [Commit], requiringParent: Bool = true) -> [Commit] {
        guard !stashes.isEmpty else { return commits }
        var positions: [String: Int] = [:]
        for (index, commit) in commits.enumerated() where positions[commit.hash] == nil {
            positions[commit.hash] = index
        }
        var inserted: [Int: [Commit]] = [:]
        for stash in stashes where positions[stash.hash] == nil {
            let base = stash.parents.first
            let baseIndex = base.flatMap { positions[$0] }
            if requiringParent, baseIndex == nil { continue }
            let byDate = commits.firstIndex { $0.date < stash.date } ?? commits.count
            inserted[min(byDate, baseIndex ?? commits.count), default: []].append(entry(for: stash))
        }
        var merged: [Commit] = []
        merged.reserveCapacity(commits.count + stashes.count)
        for (index, commit) in commits.enumerated() {
            merged += inserted[index] ?? []
            merged.append(commit)
        }
        merged += inserted[commits.count] ?? []
        return merged
    }

    private static func entry(for stash: Commit) -> Commit {
        Commit(hash: stash.hash, parents: Array(stash.parents.prefix(1)), author: stash.author, authorEmail: stash.authorEmail, date: stash.date, refs: stash.refs, subject: stash.subject)
    }
}
