import MorkData
import MorkDomain
import MorkPresentation
import Foundation

extension AppContainer {
    nonisolated static func makeBranchActionsDependencies(
        executor: GitToolCommandExecuting,
        workingCopy: WorkingCopyRepositoryProtocol,
        remote: RemoteRepositoryProtocol,
        remoteManagement: RemoteManagementRepositoryProtocol
    ) -> BranchActionsDependencies {
        let actions = BranchActionsRepositoryImpl(executor: executor)
        return BranchActionsDependencies(
            createBranch: CreateBranchFromBranchUseCase(branches: actions),
            createTag: CreateTagAtBranchUseCase(branches: actions),
            rename: RenameBranchUseCase(branches: actions, remote: remote, remotes: remoteManagement),
            fastForward: FastForwardBranchUseCase(branches: actions, workingCopy: workingCopy),
            loadPullRequestURL: LoadPullRequestURLUseCase(branches: actions)
        )
    }
}
