import MorkDomain
import Foundation

public final class WorkingCopyRepositoryImpl: WorkingCopyRepositoryProtocol {
    private static let literalPathspecs = "--literal-pathspecs"

    private let executor: GitCommandExecuting
    private let diffOptions: DiffOptionsProviding

    public init(executor: GitCommandExecuting, diffOptions: DiffOptionsProviding = DiffOptions.standard) {
        self.executor = executor
        self.diffOptions = diffOptions
    }

    public func changes() async throws -> [FileChange] {
        GitOutputParser.status(try await executor.read(["status", "--porcelain=v1", "-z", "--untracked-files=all"]))
    }

    public func ignoredFiles() async throws -> [FileChange] {
        GitOutputParser.status(try await executor.read(["status", "--porcelain=v1", "-z", "--ignored", "--untracked-files=normal"])).filter(\.isIgnored)
    }

    public func hiddenFiles(among paths: [String]) async throws -> [String] {
        guard !paths.isEmpty else { return [] }
        let output = try await executor.read([Self.literalPathspecs, "ls-files", "-v", "-z", "--"] + paths)
        return output.split(separator: "\0").compactMap { entry in
            guard let tag = entry.first, entry.dropFirst().first == " ", tag == "S" || tag.isLowercase else { return nil }
            return String(entry.dropFirst(2))
        }
    }

    public func unhide(paths: [String]) async throws {
        try await executor.write(["update-index", "--no-skip-worktree", "--"] + paths)
        try await executor.write(["update-index", "--no-assume-unchanged", "--"] + paths)
    }

    public func diff(for change: FileChange, staged: Bool) async throws -> String {
        let options = diffOptions.diffOptions().workingCopyArguments
        if staged {
            return try await executor.readLossless([Self.literalPathspecs, "diff"] + options + ["--cached", "--", change.path])
        }
        if change.isIgnored, change.path.hasSuffix("/") { return "" }
        if change.isUntracked || change.isIgnored {
            return try await executor.readLossless(["diff"] + options + ["--no-index", "--", "/dev/null", change.path], allowedExitCodes: [0, 1])
        }
        return try await executor.readLossless([Self.literalPathspecs, "diff"] + options + ["--", change.path])
    }

    public func stage(paths: [String]) async throws {
        try await executor.write([Self.literalPathspecs, "add", "--"] + paths)
    }

    public func forceStage(paths: [String]) async throws {
        try await executor.write([Self.literalPathspecs, "add", "--force", "--"] + paths)
    }

    public func stageAll() async throws {
        try await executor.write(["add", "--all"])
    }

    public func unstage(paths: [String]) async throws {
        if try await executor.hasHead() {
            try await executor.write([Self.literalPathspecs, "restore", "--staged", "--"] + paths)
        } else {
            try await executor.write([Self.literalPathspecs, "rm", "--cached", "-r", "-f", "--quiet", "--"] + paths)
        }
    }

    public func discard(_ change: FileChange) async throws {
        if change.isUntracked {
            try await executor.write([Self.literalPathspecs, "clean", "-f", "--", change.path])
        } else {
            try await executor.write([Self.literalPathspecs, "restore", "--worktree", "--", change.path])
        }
    }

    public func commit(message: String, amend: Bool) async throws {
        try await executor.write(["commit"] + (amend ? ["--amend"] : []) + ["-m", message])
    }

    public func lastCommitMessage() async throws -> String? {
        guard try await executor.hasHead() else { return nil }
        let message = try await executor.read(["log", "-1", "--format=%B"])
        return message.trimmingCharacters(in: .newlines)
    }

    public func state() async throws -> RepositoryState {
        let gitDirectory = try await executor.read(["rev-parse", "--absolute-git-dir"]).trimmingCharacters(in: .newlines)
        let exists = { (name: String) in
            FileManager.default.fileExists(atPath: (gitDirectory as NSString).appendingPathComponent(name))
        }
        if exists("rebase-merge") || exists("rebase-apply") { return .rebasing }
        if exists("MERGE_HEAD") { return .merging }
        if exists("CHERRY_PICK_HEAD") { return .cherryPicking }
        if exists("REVERT_HEAD") { return .reverting }
        return .clean
    }

    public func abortMerge() async throws {
        try await executor.write(["merge", "--abort"])
    }

    public func apply(patch: String, action: HunkAction) async throws {
        let flags = switch action {
        case .stage: ["--cached"]
        case .unstage: ["--cached", "--reverse"]
        case .discard: ["--reverse"]
        }
        try await executor.write(["apply"] + flags + ["-"], input: patch)
    }
}
