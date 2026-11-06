import MorkDomain
import Foundation

public final class RevisionRepositoryImpl: RevisionRepositoryProtocol {
    private let executor: GitCommandExecuting

    public init(executor: GitCommandExecuting) {
        self.executor = executor
    }

    public func checkout(_ commit: Commit) async throws {
        try await executor.write(["switch", "--detach", commit.hash])
    }

    public func createBranch(named name: String, at commit: Commit, checkout: Bool) async throws {
        if checkout {
            try await executor.write(["switch", "-c", name, commit.hash])
        } else {
            try await executor.write(["branch", name, commit.hash])
        }
    }

    public func createTag(named name: String, message: String, at commit: Commit) async throws {
        if message.isEmpty {
            try await executor.write(["tag", name, commit.hash])
        } else {
            try await executor.write(["tag", "-a", name, "-m", message, commit.hash])
        }
    }

    public func cherryPick(_ commit: Commit, mainline: Int?, options: CherryPickOptions) async throws {
        try await executor.write(options.arguments(revision: commit.hash, mainline: mainline))
    }

    public func revert(_ commit: Commit, mainline: Int?, options: RevertOptions) async throws {
        try await executor.write(options.arguments(revision: commit.hash, mainline: mainline))
    }

    public func cherryPick(_ commits: [Commit], mainline: Int?, options: CherryPickOptions) async throws {
        try await executor.write(options.arguments(revisions: commits.map(\.hash), mainline: mainline))
    }

    public func revert(_ commits: [Commit], mainline: Int?, options: RevertOptions) async throws {
        try await executor.write(options.arguments(revisions: commits.map(\.hash), mainline: mainline))
    }

    public func reset(to commit: Commit, mode: ResetMode) async throws {
        try await executor.write(["reset", mode.flag, commit.hash])
    }

    public func continueOperation(_ operation: RevisionOperation) async throws {
        try await executor.write([operation.subcommand, "--continue"])
    }

    public func abortOperation(_ operation: RevisionOperation) async throws {
        try await executor.write([operation.subcommand, "--abort"])
    }
}

private extension RevisionOperation {
    var subcommand: String {
        switch self {
        case .cherryPick: "cherry-pick"
        case .revert: "revert"
        }
    }
}
