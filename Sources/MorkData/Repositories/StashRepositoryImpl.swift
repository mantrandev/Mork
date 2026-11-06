import MorkDomain
import Foundation

public final class StashRepositoryImpl: StashRepositoryProtocol {
    private let executor: GitCommandExecuting

    public init(executor: GitCommandExecuting) {
        self.executor = executor
    }

    public func stashes() async throws -> [Stash] {
        GitOutputParser.stashes(try await executor.read(["stash", "list", "--format=\(GitOutputParser.stashFormat)"]))
    }

    public func save(message: String) async throws {
        try await executor.write(["stash", "push", "--include-untracked"] + (message.isEmpty ? [] : ["-m", message]))
    }

    public func apply(_ stash: Stash, drop: Bool) async throws {
        try await executor.write(["stash", drop ? "pop" : "apply", stash.reference])
    }

    public func drop(_ stash: Stash) async throws {
        try await executor.write(["stash", "drop", stash.reference])
    }
}
