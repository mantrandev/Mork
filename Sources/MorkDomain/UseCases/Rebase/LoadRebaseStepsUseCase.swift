import Foundation

public protocol LoadRebaseStepsUseCaseProtocol: Sendable {
    func execute(base: RebaseBase, branch: Branch?) async throws -> RebaseRange
}

public final class LoadRebaseStepsUseCase: LoadRebaseStepsUseCaseProtocol {
    private let rebase: RebaseRepositoryProtocol
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(rebase: RebaseRepositoryProtocol, workingCopy: WorkingCopyRepositoryProtocol) {
        self.rebase = rebase
        self.workingCopy = workingCopy
    }

    public func execute(base: RebaseBase, branch: Branch?) async throws -> RebaseRange {
        guard let branch else { throw GitDomainError.detachedHead }
        if case let .branch(onto) = base, onto.fullName == branch.fullName { throw RebaseError.nothingToRebase }
        try await workingCopy.requireCleanState()
        let range = try await rebase.steps(from: base)
        let steps = range.filter { !$0.commit.isMerge }
        guard !steps.isEmpty else { throw RebaseError.nothingToRebase }
        return RebaseRange(steps: steps, skippedMerges: range.map(\.commit).filter(\.isMerge))
    }
}
