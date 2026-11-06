import Foundation

public protocol FastForwardBranchUseCaseProtocol: Sendable {
    func execute(branch: Branch) async throws
}

public final class FastForwardBranchUseCase: FastForwardBranchUseCaseProtocol {
    private let branches: BranchActionsRepositoryProtocol
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(branches: BranchActionsRepositoryProtocol, workingCopy: WorkingCopyRepositoryProtocol) {
        self.branches = branches
        self.workingCopy = workingCopy
    }

    public func execute(branch: Branch) async throws {
        guard !branch.isRemote, let upstream = branch.upstream, !branch.isUpstreamGone else {
            throw BranchActionError.noUpstream(branch.name)
        }
        if branch.isCurrent { try await workingCopy.requireCleanState() }
        guard try await branches.countCommits(in: branch.name, missingFrom: upstream) == 0 else {
            throw BranchActionError.notFastForward(branch: branch.name, upstream: upstream)
        }
        if branch.isCurrent {
            try await branches.fastForwardCurrentBranch(to: upstream)
        } else {
            try await branches.fastForward(branch: branch.name, to: upstream)
        }
    }
}
