import MorkDomain
import Foundation

public final class RemoteRepositoryImpl: RemoteRepositoryProtocol {
    private let executor: GitCommandExecuting

    public init(executor: GitCommandExecuting) {
        self.executor = executor
    }

    public func remotes() async throws -> [String] {
        GitOutputParser.lines(try await executor.read(["remote"]))
    }

    public func fetch() async throws {
        try await executor.write(["fetch", "--all", "--prune"])
    }

    public func pull() async throws {
        try await executor.write(["pull", "--ff-only"])
    }

    public func push(_ branch: Branch, setUpstreamTo remote: String?) async throws {
        if let remote {
            try await executor.write(["push", "--set-upstream", remote, branch.name])
        } else {
            try await executor.write(["push"])
        }
    }

    public func pull(mode: PullMode) async throws {
        try await executor.write(mode.arguments)
    }

    public func pull(options: PullOptions) async throws {
        try await executor.write(options.arguments)
    }

    public func push(options: PushOptions) async throws {
        try await executor.write(options.arguments)
    }

    public func fetch(options: FetchOptions) async throws {
        try await executor.write(options.arguments)
    }

    public func pushTag(named name: String, to remote: String) async throws {
        try await executor.write(["push", remote, "refs/tags/\(name)"])
    }
}
