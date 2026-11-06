import Foundation

public protocol RebaseBranchUseCaseProtocol: Sendable {
    func execute(onto branch: Branch, current: Branch?, autostash: Bool) async throws
}

public final class RebaseBranchUseCase: RebaseBranchUseCaseProtocol {
    private let rebase: RebaseRepositoryProtocol
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(rebase: RebaseRepositoryProtocol, workingCopy: WorkingCopyRepositoryProtocol) {
        self.rebase = rebase
        self.workingCopy = workingCopy
    }

    public func execute(onto branch: Branch, current: Branch?, autostash: Bool) async throws {
        guard let current else { throw GitDomainError.detachedHead }
        guard branch.fullName != current.fullName else { return }
        try await workingCopy.requireCleanState()
        if !autostash { try await workingCopy.requireNoUncommittedChanges() }
        try await rebase.rebase(onto: branch, autostash: autostash)
    }
}
