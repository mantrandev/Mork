import MorkDomain
import Foundation

public final class HistoryRepositoryImpl: HistoryRepositoryProtocol {
    let executor: GitCommandExecuting
    private let diffOptions: DiffOptionsProviding

    public init(executor: GitCommandExecuting, diffOptions: DiffOptionsProviding = DiffOptions.standard) {
        self.executor = executor
        self.diffOptions = diffOptions
    }

    public func history(limit: Int, options: HistoryOptions) async throws -> [Commit] {
        try await history(limit: limit, skip: 0, options: options)
    }

    public func history(limit: Int, skip: Int, options: HistoryOptions) async throws -> [Commit] {
        guard try await executor.hasHead() else { return [] }
        return try await markingSyncStatus(unmarkedHistory(limit: limit, skip: skip, options: options))
    }

    public func unmarkedHistory(limit: Int, options: HistoryOptions) async throws -> [Commit] {
        try await unmarkedHistory(limit: limit, skip: 0, options: options)
    }

    private func unmarkedHistory(limit: Int, skip: Int, options: HistoryOptions) async throws -> [Commit] {
        if options.showsLostCommits {
            guard try await executor.hasHead() else { return [] }
        }
        let scope = try await scope(options, limit: skip + limit)
        let window = skip > 0 ? ["--skip=\(skip)"] : []
        let commits = scope.mark(GitOutputParser.commits(try await executor.read(
            ["log", "--ignore-missing"] + scope.arguments + ["--date-order"] + window + ["-n", "\(limit)", "--pretty=format:\(GitOutputParser.historyFormat)"]
        )))
        guard !options.hidesStashes else { return commits }
        return StashHistory.merge(try await stashCommits(), into: commits)
    }

    func stashCommits(_ filter: [String] = []) async throws -> [Commit] {
        GitOutputParser.commits(try await executor.read(["stash", "list", "--format=\(GitOutputParser.stashHistoryFormat)"] + filter))
    }

    public func details(of commit: Commit) async throws -> String {
        try await executor.read(["show", "--stat", "--patch", "-M", "--diff-merges=first-parent"] + diffOptions.diffOptions().arguments + ["--format=fuller", commit.hash])
    }

    public func fullMessage(of commit: Commit) async throws -> String {
        try await executor.read(["show", "-s", "--format=%B", commit.hash]).trimmingCharacters(in: .newlines)
    }

    public func changedFiles(in commit: Commit) async throws -> [CommitFileChange] {
        GitOutputParser.nameStatus(try await executor.read(["show", "--name-status", "-z", "-M", "--diff-merges=first-parent", "--format=", commit.hash]))
    }

    public func diff(of file: CommitFileChange, in commit: Commit) async throws -> String {
        let paths = [file.originalPath, file.path].compactMap { $0 }
        return try await executor.read(["--literal-pathspecs", "show", "-M", "--diff-merges=first-parent"] + diffOptions.diffOptions().arguments + ["--format=", commit.hash, "--"] + paths)
    }
}
