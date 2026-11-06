import Foundation

public protocol RunInteractiveRebaseUseCaseProtocol: Sendable {
    func execute(base: RebaseBase, steps: [RebaseStep], options: InteractiveRebaseOptions) async throws
}

public final class RunInteractiveRebaseUseCase: RunInteractiveRebaseUseCaseProtocol {
    private let rebase: RebaseRepositoryProtocol
    private let workingCopy: WorkingCopyRepositoryProtocol
    private let branches: BranchActionsRepositoryProtocol

    public init(rebase: RebaseRepositoryProtocol, workingCopy: WorkingCopyRepositoryProtocol, branches: BranchActionsRepositoryProtocol) {
        self.rebase = rebase
        self.workingCopy = workingCopy
        self.branches = branches
    }

    public func execute(base: RebaseBase, steps: [RebaseStep], options: InteractiveRebaseOptions) async throws {
        let todo = try RebaseTodoBuilder.build(steps)
        try await workingCopy.requireCleanState()
        if !options.autostash { try await workingCopy.requireNoUncommittedChanges() }
        if let backup = options.backupBranch {
            try await branches.createBranch(named: backup, startPoint: "HEAD", checkout: false)
        }
        try await rebase.startInteractiveRebase(onto: base, todo: todo, autostash: options.autostash, updateRefs: options.updateRefs)
    }
}

extension WorkingCopyRepositoryProtocol {
    func requireNoUncommittedChanges() async throws {
        guard try await !changes().contains(where: \.isUncommitted) else { throw RebaseError.uncommittedChanges }
    }
}
