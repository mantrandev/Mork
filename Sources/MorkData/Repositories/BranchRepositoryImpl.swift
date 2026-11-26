import MorkDomain
import Foundation

public final class BranchRepositoryImpl: BranchRepositoryProtocol {
    private let executor: GitStreamingCommandExecuting

    public init(executor: GitStreamingCommandExecuting) {
        self.executor = executor
    }

    public func branches() async throws -> [Branch] {
        try await Self.branches(using: executor)
    }

    static func branches(using executor: GitCommandExecuting) async throws -> [Branch] {
        GitOutputParser.branches(try await executor.read([
            "for-each-ref", "--format=\(GitOutputParser.branchFormat)", "refs/heads", "refs/remotes"
        ]))
    }

    public func create(named name: String) async throws {
        try await executor.write(["switch", "-c", name])
    }

    public func switchTo(_ branch: Branch, progress: @escaping @Sendable (String) -> Void) async throws {
        try await switching(["switch", "--progress", branch.name], progress: progress)
    }

    public func track(_ remoteBranch: Branch, progress: @escaping @Sendable (String) -> Void) async throws {
        try await switching(["switch", "--progress", "--track", remoteBranch.name], progress: progress)
    }

    private func switching(_ arguments: [String], progress: @escaping @Sendable (String) -> Void) async throws {
        _ = try await executor.run(arguments, kind: .write, allowedExitCodes: [0], onProgress: progress)
    }

    public func delete(_ branch: Branch, force: Bool) async throws {
        try await executor.write(["branch", force ? "-D" : "-d", branch.name])
    }

    public func merge(_ branch: Branch) async throws {
        try await executor.write(["merge", "--no-edit", branch.name])
    }
}
