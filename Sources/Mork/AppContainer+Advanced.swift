import MorkData
import MorkDomain
import MorkPresentation
import Foundation

extension AppContainer {
    nonisolated static func makeAdvancedDependencies(executor: GitToolCommandExecuting, repository: URL, diffOptions: DiffOptionsProviding) -> AdvancedDependencies {
        let lfs = LFSRepositoryImpl(executor: executor)
        let flow = GitFlowRepositoryImpl(executor: executor)
        return AdvancedDependencies(
            lfs: LFSDependencies(
                loadInstallation: LoadLFSInstallationUseCase(lfs: lfs),
                initialize: InitializeLFSUseCase(lfs: lfs),
                loadPatterns: LoadLFSPatternsUseCase(lfs: lfs),
                track: TrackLFSPatternUseCase(lfs: lfs),
                untrack: UntrackLFSPatternUseCase(lfs: lfs),
                transfer: TransferLFSObjectsUseCase(lfs: lfs),
                loadFiles: LoadLFSFilesUseCase(lfs: lfs)
            ),
            flow: GitFlowDependencies(
                loadContext: LoadGitFlowContextUseCase(flow: flow),
                runSteps: RunGitFlowStepsUseCase(flow: flow),
                planLeanFinish: PlanLeanFinishUseCase(branches: BranchActionsRepositoryImpl(executor: executor))
            ),
            loadTreemap: LoadTreemapUseCase(treemap: TreemapRepositoryImpl(executor: executor)),
            runBenchmark: RunPerformanceBenchmarkUseCase(benchmark: BenchmarkRepositoryImpl(directory: repository) { recorder in
                _ = try await makeSnapshotLoader(executor: recorder, repository: repository, diffOptions: diffOptions)
                    .execute(historyLimit: RepositoryViewModel.historyLimit)
            })
        )
    }

    nonisolated static func makeSnapshotLoader(executor: GitStreamingCommandExecuting, repository: URL, diffOptions: DiffOptionsProviding) -> LoadRepositorySnapshotUseCase {
        LoadRepositorySnapshotUseCase(
            workingCopy: WorkingCopyRepositoryImpl(executor: executor, diffOptions: diffOptions),
            history: HistoryRepositoryImpl(executor: executor, diffOptions: diffOptions),
            branches: BranchRepositoryImpl(executor: executor),
            stashes: StashRepositoryImpl(executor: executor),
            tags: TagRepositoryImpl(executor: executor),
            remotes: RemoteManagementRepositoryImpl(executor: executor),
            worktrees: WorktreeRepositoryImpl(executor: executor),
            submodules: SubmoduleRepositoryImpl(executor: executor, root: repository),
            bisect: BisectRepositoryImpl(executor: executor)
        )
    }
}
