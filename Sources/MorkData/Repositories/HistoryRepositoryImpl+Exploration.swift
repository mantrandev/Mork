import MorkDomain
import Foundation

struct HistoryScope {
    let arguments: [String]
    let lost: Set<String>

    func mark(_ commits: [Commit]) -> [Commit] {
        guard !lost.isEmpty else { return commits }
        return commits.map { commit in
            guard lost.contains(commit.hash) else { return commit }
            return Commit(hash: commit.hash, parents: commit.parents, author: commit.author, authorEmail: commit.authorEmail, date: commit.date, refs: commit.refs, subject: commit.subject, isLost: true)
        }
    }
}

extension HistoryRepositoryImpl: CommitSearchRepositoryProtocol {
    public func search(_ query: CommitSearchQuery, options: HistoryOptions, limit: Int) async throws -> [Commit] {
        guard try await executor.hasHead() else { return [] }
        let scope = try await scope(options, limit: limit)
        let format = "--pretty=format:\(GitOutputParser.historyFormat)"
        let output: String
        switch query.mode {
        case .hash:
            let hashes = GitOutputParser.lines(try await executor.read(["rev-list"] + scope.arguments))
                .filter { $0.hasPrefix(query.text) }
                .prefix(limit)
            output = hashes.isEmpty ? "" : try await executor.read(["log", "--no-walk=sorted", format] + hashes)
        case .message, .author, .content, .regex:
            output = try await executor.read(["log"] + scope.arguments + ["--date-order", "-n", "\(limit)", format] + Self.filter(query))
        }
        let commits = try await markingSyncStatus(scope.mark(GitOutputParser.commits(output)))
        guard !options.hidesStashes, !options.currentBranchOnly, options.filteredBranches.isEmpty else { return commits }
        return StashHistory.merge(try await matchingStashes(query), into: commits, requiringParent: false)
    }

    private func matchingStashes(_ query: CommitSearchQuery) async throws -> [Commit] {
        switch query.mode {
        case .hash: try await stashCommits().filter { $0.hash.hasPrefix(query.text) }
        case .message, .author, .content, .regex: try await stashCommits(Self.filter(query))
        }
    }

    public func commit(revision: String) async throws -> Commit {
        let output = try await executor.read(["log", "-n", "1", "--pretty=format:\(GitOutputParser.historyFormat)", revision, "--"])
        guard let commit = GitOutputParser.commits(output).first else {
            throw GitDomainError.commandFailed(command: "git log -n 1 \(revision)", exitCode: 0, message: "\(revision) is not a commit.")
        }
        return commit
    }

    func scope(_ options: HistoryOptions, limit: Int) async throws -> HistoryScope {
        var arguments = options.revisionArguments
        if options.firstParentOnly { arguments.append("--first-parent") }
        guard options.showsLostCommits else { return HistoryScope(arguments: arguments, lost: []) }
        var seen: Set<String> = []
        let tips = GitOutputParser.lines(try await executor.read(["reflog", "-n", "\(limit)", "--format=%H"]))
            .filter { seen.insert($0).inserted }
        guard !tips.isEmpty else { return HistoryScope(arguments: arguments, lost: []) }
        let lost = GitOutputParser.lines(try await executor.read(["rev-list"] + tips + ["--not", "--all"]))
        return HistoryScope(arguments: lost + arguments, lost: Set(lost))
    }

    private static func filter(_ query: CommitSearchQuery) -> [String] {
        switch query.mode {
        case .message: ["-i", "-F", "--grep=\(query.text)"]
        case .author: ["-i", "-F", "--author=\(query.text)"]
        case .content: ["-S\(query.text)"]
        case .regex: ["-G\(query.text)"]
        case .hash: []
        }
    }
}
