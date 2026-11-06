import MorkDomain
import Foundation

public struct RemoteManagementDependencies: Sendable {
    public let addRemote: AddRemoteUseCaseProtocol
    public let editRemote: EditRemoteUseCaseProtocol
    public let removeRemote: RemoveRemoteUseCaseProtocol
    public let fetchRemote: FetchRemoteUseCaseProtocol
    public let pruneRemote: PruneRemoteUseCaseProtocol
    public let deleteRemoteBranch: DeleteRemoteBranchUseCaseProtocol
    public let setUpstream: SetUpstreamUseCaseProtocol
    public let unsetUpstream: UnsetUpstreamUseCaseProtocol

    public init(
        addRemote: AddRemoteUseCaseProtocol,
        editRemote: EditRemoteUseCaseProtocol,
        removeRemote: RemoveRemoteUseCaseProtocol,
        fetchRemote: FetchRemoteUseCaseProtocol,
        pruneRemote: PruneRemoteUseCaseProtocol,
        deleteRemoteBranch: DeleteRemoteBranchUseCaseProtocol,
        setUpstream: SetUpstreamUseCaseProtocol,
        unsetUpstream: UnsetUpstreamUseCaseProtocol
    ) {
        self.addRemote = addRemote
        self.editRemote = editRemote
        self.removeRemote = removeRemote
        self.fetchRemote = fetchRemote
        self.pruneRemote = pruneRemote
        self.deleteRemoteBranch = deleteRemoteBranch
        self.setUpstream = setUpstream
        self.unsetUpstream = unsetUpstream
    }
}

public struct WorktreeDependencies: Sendable {
    public let addWorktree: AddWorktreeUseCaseProtocol
    public let removeWorktree: RemoveWorktreeUseCaseProtocol
    public let lockWorktree: LockWorktreeUseCaseProtocol
    public let unlockWorktree: UnlockWorktreeUseCaseProtocol
    public let pruneWorktrees: PruneWorktreesUseCaseProtocol

    public init(
        addWorktree: AddWorktreeUseCaseProtocol,
        removeWorktree: RemoveWorktreeUseCaseProtocol,
        lockWorktree: LockWorktreeUseCaseProtocol,
        unlockWorktree: UnlockWorktreeUseCaseProtocol,
        pruneWorktrees: PruneWorktreesUseCaseProtocol
    ) {
        self.addWorktree = addWorktree
        self.removeWorktree = removeWorktree
        self.lockWorktree = lockWorktree
        self.unlockWorktree = unlockWorktree
        self.pruneWorktrees = pruneWorktrees
    }
}

public struct SubmoduleDependencies: Sendable {
    public let updateSubmodules: UpdateSubmodulesUseCaseProtocol
    public let addSubmodule: AddSubmoduleUseCaseProtocol
    public let syncSubmodules: SyncSubmodulesUseCaseProtocol

    public init(
        updateSubmodules: UpdateSubmodulesUseCaseProtocol,
        addSubmodule: AddSubmoduleUseCaseProtocol,
        syncSubmodules: SyncSubmodulesUseCaseProtocol
    ) {
        self.updateSubmodules = updateSubmodules
        self.addSubmodule = addSubmodule
        self.syncSubmodules = syncSubmodules
    }
}

public struct WorkspaceDependencies: Sendable {
    public let remotes: RemoteManagementDependencies
    public let worktrees: WorktreeDependencies
    public let submodules: SubmoduleDependencies
    public let settings: RepositorySettingsDependencies

    public init(remotes: RemoteManagementDependencies, worktrees: WorktreeDependencies, submodules: SubmoduleDependencies, settings: RepositorySettingsDependencies) {
        self.remotes = remotes
        self.worktrees = worktrees
        self.settings = settings
        self.submodules = submodules
    }
}
