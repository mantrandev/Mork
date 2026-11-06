import Foundation

public struct Worktree: Identifiable, Hashable, Sendable {
    public let path: String
    public let head: String?
    public let branch: String?
    public let isBare: Bool
    public let isMain: Bool
    public let lockReason: String?
    public let prunableReason: String?

    public init(
        path: String,
        head: String? = nil,
        branch: String? = nil,
        isBare: Bool = false,
        isMain: Bool = false,
        lockReason: String? = nil,
        prunableReason: String? = nil
    ) {
        self.path = path
        self.head = head
        self.branch = branch
        self.isBare = isBare
        self.isMain = isMain
        self.lockReason = lockReason
        self.prunableReason = prunableReason
    }

    public var id: String { path }
    public var name: String { URL(fileURLWithPath: path).lastPathComponent }
    public var isDetached: Bool { branch == nil && !isBare }
    public var isLocked: Bool { lockReason != nil }
    public var isPrunable: Bool { prunableReason != nil }
    public var shortHead: String? { head.map { String($0.prefix(7)) } }

    public func isLocated(at url: URL) -> Bool {
        Self.canonical(URL(fileURLWithPath: path)) == Self.canonical(url)
    }

    private static func canonical(_ url: URL) -> String {
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        return path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }
}

public enum WorktreeCheckout: Equatable, Sendable {
    case newBranch(String, startPoint: String?)
    case existingBranch(String)
}

public struct AddWorktreeRequest: Equatable, Sendable {
    public let path: String
    public let checkout: WorktreeCheckout

    public init(path: String, checkout: WorktreeCheckout) {
        self.path = path
        self.checkout = checkout
    }

    public var arguments: [String] {
        switch checkout {
        case let .newBranch(name, startPoint):
            ["worktree", "add", "-b", name, path] + (startPoint.map { [$0] } ?? [])
        case let .existingBranch(name):
            ["worktree", "add", path, name]
        }
    }
}

public enum WorktreeRemoval: Equatable, Sendable {
    case removed
    case needsForce
}

public enum WorktreeError: LocalizedError, Equatable, Sendable {
    case emptyPath
    case relativePath(String)
    case emptyBranchName
    case cannotRemoveMain
    case cannotLockMain
    case locked(String)

    public var errorDescription: String? {
        switch self {
        case .emptyPath:
            "Choose a folder for the new worktree."
        case let .relativePath(path):
            "\(path) is not a full path. Choose a folder or type a path that starts with /."
        case .emptyBranchName:
            "Branch name cannot be empty."
        case .cannotRemoveMain:
            "The main worktree holds the repository itself and cannot be removed."
        case .cannotLockMain:
            "The main worktree cannot be locked; only linked worktrees can."
        case let .locked(path):
            "\(path) is locked. Unlock it first (git worktree unlock)."
        }
    }
}
