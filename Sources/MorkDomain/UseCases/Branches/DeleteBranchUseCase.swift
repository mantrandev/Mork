import Foundation

public protocol DeleteBranchUseCaseProtocol: Sendable {
    func execute(branch: Branch, force: Bool) async throws
}

public enum BranchDeletionError: LocalizedError, Sendable, Equatable {
    case notFullyMerged(branch: String, target: String, commits: Int)

    public var errorDescription: String? {
        switch self {
        case let .notFullyMerged(branch, target, commits):
            let count = commits == 1 ? "1 commit that is" : "\(commits) commits that are"
            return "'\(branch)' has \(count) not in \(target). git branch -d refuses to delete it so those commits are not lost. Force Delete runs git branch -D and drops them anyway."
        }
    }
}

public final class DeleteBranchUseCase: DeleteBranchUseCaseProtocol {
    private let branches: BranchRepositoryProtocol
    private let actions: BranchActionsRepositoryProtocol

    public init(branches: BranchRepositoryProtocol, actions: BranchActionsRepositoryProtocol) {
        self.branches = branches
        self.actions = actions
    }

    public func execute(branch: Branch, force: Bool) async throws {
        guard !branch.isRemote else { throw GitDomainError.cannotDeleteRemoteBranch }
        guard !branch.isCurrent else { throw GitDomainError.cannotDeleteCurrentBranch }
        let needsForce = force ? true : try await requireMerged(branch)
        try await branches.delete(branch, force: needsForce)
    }

    private func requireMerged(_ branch: Branch) async throws -> Bool {
        let target = branch.isUpstreamGone ? nil : branch.upstream
        let commits = try await actions.countCommits(in: branch.fullName, missingFrom: target ?? "HEAD")
        guard commits > 0 else { return false }
        if await hasChanges(of: branch, in: target ?? "HEAD") { return true }
        throw BranchDeletionError.notFullyMerged(branch: branch.name, target: target ?? "the current branch", commits: commits)
    }

    private func hasChanges(of branch: Branch, in target: String) async -> Bool {
        if (try? await actions.isContentMerged(branch.fullName, into: target)) == true { return true }
        guard let remote = branch.upstream?.split(separator: "/").first.map(String.init),
              let name = try? await actions.defaultBranch(ofRemote: remote) else { return false }
        return (try? await actions.isContentMerged(branch.fullName, into: "refs/remotes/\(remote)/\(name)")) == true
    }
}
