import MorkDomain
import Foundation

public final class BranchRepositoryImpl: BranchRepositoryProtocol {
    private let executor: GitCommandExecuting

    public init(executor: GitCommandExecuting) {
        self.executor = executor
    }

    public func branches() async throws -> [Branch] {
        GitOutputParser.branches(try await executor.read([
            "for-each-ref", "--format=\(GitOutputParser.branchFormat)", "refs/heads", "refs/remotes"
        ]))
    }

    public func create(named name: String) async throws {
        try await executor.write(["switch", "-c", name])
    }

    public func switchTo(_ branch: Branch) async throws {
        try await executor.write(["switch", branch.name])
    }

    public func track(_ remoteBranch: Branch) async throws {
        try await executor.write(["switch", "--track", remoteBranch.name])
    }

    public func delete(_ branch: Branch, force: Bool) async throws {
        try await executor.write(["branch", force ? "-D" : "-d", branch.name])
    }

    public func merge(_ branch: Branch) async throws {
        try await executor.write(["merge", "--no-edit", branch.name])
    }
}
