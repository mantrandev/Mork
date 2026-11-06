import MorkDomain
import Foundation

public struct RemoteForm: Equatable, Sendable {
    public let original: Remote?
    public let existingNames: [String]
    public var name: String
    public var url: String
    public var pushURL: String
    public var fetchAfterAdd = true

    public init(existingNames: [String]) {
        original = nil
        self.existingNames = existingNames
        name = ""
        url = ""
        pushURL = ""
    }

    public init(editing remote: Remote, existingNames: [String]) {
        original = remote
        self.existingNames = existingNames
        let edit = RemoteEdit(remote: remote)
        name = edit.name
        url = edit.fetchURL
        pushURL = edit.pushURL
    }

    public var isEditing: Bool { original != nil }
    public var edit: RemoteEdit { RemoteEdit(name: name, fetchURL: url, pushURL: pushURL) }

    public var nameProblem: String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let others = existingNames.filter { $0 != original?.name }
        return RemoteNameRules.problem(with: trimmed, existing: others)?.errorDescription
    }

    public var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              nameProblem == nil else { return false }
        guard let original else { return true }
        return edit != RemoteEdit(remote: original)
    }
}

public struct WorktreeForm: Equatable, Sendable {
    public enum Mode: String, CaseIterable, Identifiable, Sendable {
        case newBranch = "New Branch"
        case existingBranch = "Existing Branch"

        public var id: String { rawValue }
    }

    public let repository: URL
    public let availableBranches: [String]
    public var mode: Mode = .newBranch
    public var branchName = ""
    public var startPoint = ""
    public var existingBranch: String
    private var customPath: String?

    public init(repository: URL, branches: [Branch], worktrees: [Worktree]) {
        self.repository = repository
        let checkedOut = Set(worktrees.compactMap(\.branch))
        availableBranches = branches.filter { !$0.isRemote && !checkedOut.contains($0.name) }.map(\.name)
        existingBranch = availableBranches.first ?? ""
    }

    public init(repository: URL, branches: [Branch], worktrees: [Worktree], checkingOut branch: Branch) {
        self.init(repository: repository, branches: branches, worktrees: worktrees)
        let local = branch.isRemote ? branch.localName : branch.name
        if branches.contains(where: { !$0.isRemote && $0.name == local }) {
            mode = .existingBranch
            existingBranch = local
        } else {
            branchName = local
            startPoint = branch.name
        }
    }

    public var path: String {
        get { customPath ?? suggestedPath }
        set { customPath = newValue }
    }

    public var selectedBranch: String { mode == .newBranch ? branchName : existingBranch }

    public var suggestedPath: String {
        let branch = selectedBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !branch.isEmpty else { return "" }
        let suffix = branch.map { $0 == "/" || $0.isWhitespace ? "-" : String($0) }.joined()
        return repository.deletingLastPathComponent().appendingPathComponent("\(repository.lastPathComponent)-\(suffix)").path
    }

    public var request: AddWorktreeRequest? {
        let path = NSString(string: path.trimmingCharacters(in: .whitespacesAndNewlines)).expandingTildeInPath
        let branch = selectedBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard path.hasPrefix("/"), !branch.isEmpty else { return nil }
        switch mode {
        case .newBranch:
            let start = startPoint.trimmingCharacters(in: .whitespacesAndNewlines)
            return AddWorktreeRequest(path: path, checkout: .newBranch(branch, startPoint: start.isEmpty ? nil : start))
        case .existingBranch:
            return AddWorktreeRequest(path: path, checkout: .existingBranch(branch))
        }
    }

    public var canAdd: Bool { request != nil }
}

public struct SubmoduleForm: Equatable, Sendable {
    public var url = ""
    private var customPath: String?

    public init() {}

    public var path: String {
        get { customPath ?? CloneRepositoryUseCase.suggestedDirectoryName(for: url) }
        set { customPath = newValue }
    }

    public var canAdd: Bool {
        !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public struct SubmoduleUpdate: Equatable, Sendable {
    public internal(set) var isRunning = false
    public internal(set) var progress = GitProgressLog()

    public init() {}
}

public struct WorktreeRow: Identifiable, Equatable, Sendable {
    public let worktree: Worktree
    public let isCurrent: Bool

    public var id: String { worktree.id }
}

public struct RemoteSection: Identifiable, Equatable, Sendable {
    public let name: String
    public let remote: Remote?
    public let nodes: [BranchNode]

    public var id: String { name }
}
