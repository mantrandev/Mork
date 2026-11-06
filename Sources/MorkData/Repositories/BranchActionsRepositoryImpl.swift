import MorkDomain
import Foundation

public final class BranchActionsRepositoryImpl: BranchActionsRepositoryProtocol {
    private static let notSymbolic: Set<Int32> = [0, 1]
    private static let cleanOrConflicted: Set<Int32> = [0, 1]

    private let executor: GitCommandExecuting

    public init(executor: GitCommandExecuting) {
        self.executor = executor
    }

    public func createBranch(named name: String, startPoint: String, checkout: Bool) async throws {
        try await executor.write(checkout ? ["switch", "-c", name, startPoint] : ["branch", name, startPoint])
    }

    public func createTag(named name: String, message: String, at revision: String) async throws {
        try await executor.write(message.isEmpty ? ["tag", name, revision] : ["tag", "-a", name, "-m", message, revision])
    }

    public func renameBranch(_ name: String, to newName: String) async throws {
        try await executor.write(["branch", "-m", name, newName])
    }

    public func countCommits(in branch: String, missingFrom upstream: String) async throws -> Int {
        let output = try await executor.read(["rev-list", "--count", "\(upstream)..\(branch)"])
        return Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    public func fastForwardCurrentBranch(to upstream: String) async throws {
        try await executor.write(["merge", "--ff-only", upstream])
    }

    public func fastForward(branch: String, to upstream: String) async throws {
        try await executor.write(["fetch", ".", "\(upstream):\(branch)"])
    }

    public func isContentMerged(_ branch: String, into target: String) async throws -> Bool {
        let merged = try await executor.read(["merge-tree", "--write-tree", "--no-messages", target, branch], allowedExitCodes: Self.cleanOrConflicted)
        let tree = try await executor.read(["rev-parse", "\(target)^{tree}"])
        let mergedTree = merged.split(separator: "\n").first.map(String.init) ?? ""
        return !mergedTree.isEmpty && mergedTree == tree.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func defaultBranch(ofRemote remote: String) async throws -> String? {
        let output = try await executor.read(["symbolic-ref", "--quiet", "--short", "refs/remotes/\(remote)/HEAD"], allowedExitCodes: Self.notSymbolic)
        let reference = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = remote + "/"
        guard reference.hasPrefix(prefix), reference.count > prefix.count else { return nil }
        return String(reference.dropFirst(prefix.count))
    }
}
