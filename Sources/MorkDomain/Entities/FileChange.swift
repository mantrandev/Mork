import Foundation

public struct FileChange: Identifiable, Hashable, Sendable {
    public let path: String
    public let originalPath: String?
    public let index: Character
    public let worktree: Character

    public init(path: String, originalPath: String? = nil, index: Character, worktree: Character) {
        self.path = path
        self.originalPath = originalPath
        self.index = index
        self.worktree = worktree
    }

    public var id: String { path }
    public var isUntracked: Bool { index == "?" }
    public var isIgnored: Bool { index == "!" }
    public var isStaged: Bool { index != " " && index != "?" && !isIgnored && !isConflicted }
    public var hasWorktreeChanges: Bool { (worktree != " " && !isIgnored) || isConflicted }

    public var isConflicted: Bool {
        index == "U" || worktree == "U" || (index == "A" && worktree == "A") || (index == "D" && worktree == "D")
    }
}
