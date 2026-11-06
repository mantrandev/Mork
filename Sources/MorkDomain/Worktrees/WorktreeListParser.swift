import Foundation

public enum WorktreeListParser {
    public static func parse(_ output: String) -> [Worktree] {
        var worktrees: [Worktree] = []
        var record: [String] = []
        for field in output.split(separator: "\0", omittingEmptySubsequences: false).map(String.init) {
            if field.isEmpty {
                if let worktree = worktree(from: record, isMain: worktrees.isEmpty) { worktrees.append(worktree) }
                record = []
            } else {
                record.append(field)
            }
        }
        if let worktree = worktree(from: record, isMain: worktrees.isEmpty) { worktrees.append(worktree) }
        return worktrees
    }

    private static func worktree(from record: [String], isMain: Bool) -> Worktree? {
        var path: String?
        var head: String?
        var branch: String?
        var isBare = false
        var lockReason: String?
        var prunableReason: String?
        for line in record {
            let (key, value) = split(line)
            switch key {
            case "worktree": path = value
            case "HEAD": head = value
            case "branch": branch = value.map { $0.hasPrefix("refs/heads/") ? String($0.dropFirst("refs/heads/".count)) : $0 }
            case "bare": isBare = true
            case "locked": lockReason = value ?? ""
            case "prunable": prunableReason = value ?? ""
            default: break
            }
        }
        guard let path else { return nil }
        return Worktree(
            path: path,
            head: head,
            branch: branch,
            isBare: isBare,
            isMain: isMain,
            lockReason: lockReason,
            prunableReason: prunableReason
        )
    }

    private static func split(_ line: String) -> (String, String?) {
        guard let space = line.firstIndex(of: " ") else { return (line, nil) }
        return (String(line[..<space]), String(line[line.index(after: space)...]))
    }
}
