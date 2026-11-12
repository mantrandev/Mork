import MorkDomain
import Foundation

public struct RepositoryDependencies: Sendable {
    public let loadSnapshot: LoadRepositorySnapshotUseCaseProtocol
    public let loadFileDiff: LoadFileDiffUseCaseProtocol
    public let loadCommitDetails: LoadCommitDetailsUseCaseProtocol
    public let stageFiles: StageFilesUseCaseProtocol
    public let unstageFiles: UnstageFilesUseCaseProtocol
    public let stageAllChanges: StageAllChangesUseCaseProtocol
    public let discardFileChanges: DiscardFileChangesUseCaseProtocol
    public let commitChanges: CommitChangesUseCaseProtocol
    public let loadLastCommitMessage: LoadLastCommitMessageUseCaseProtocol
    public let abortMerge: AbortMergeUseCaseProtocol
    public let createBranch: CreateBranchUseCaseProtocol
    public let checkoutBranch: CheckoutBranchUseCaseProtocol
    public let deleteBranch: DeleteBranchUseCaseProtocol
    public let mergeBranch: MergeBranchUseCaseProtocol
    public let fetchRemotes: FetchRemotesUseCaseProtocol
    public let pullBranch: PullBranchUseCaseProtocol
    public let pushBranch: PushBranchUseCaseProtocol
    public let stashChanges: StashChangesUseCaseProtocol
    public let applyStash: ApplyStashUseCaseProtocol
    public let dropStash: DropStashUseCaseProtocol
    public let createTag: CreateTagUseCaseProtocol
    public let deleteTag: DeleteTagUseCaseProtocol
    public let runGitCommand: RunGitCommandUseCaseProtocol
    public let loadCommitSummary: LoadCommitSummaryUseCaseProtocol
    public let loadCommitFileDiff: LoadCommitFileDiffUseCaseProtocol
    public let applyHunk: ApplyHunkUseCaseProtocol
    public let revisions: RevisionDependencies
    public let watchRepository: WatchRepositoryUseCaseProtocol
    public let rebase: RebaseDependencies
    public let remoteOptions: RemoteOptionsDependencies
    public let exploration: ExplorationDependencies
    public let conflicts: ConflictDependencies
    public let tools: WorkingCopyToolsDependencies
    public let workspace: WorkspaceDependencies
    public let bisect: BisectDependencies
    public let statistics: StatisticsDependencies
    public let loadHistoryPage: LoadHistoryPageUseCaseProtocol
    public let integration: IntegrationDependencies
    public let commit: CommitDependencies
    public let advanced: AdvancedDependencies
    public let branchActions: BranchActionsDependencies
    public let tagActions: TagActionsDependencies
    public let sidebarOptions: SidebarOptionsDependencies
    public let range: CommitRangeDependencies

    public init(
        loadSnapshot: LoadRepositorySnapshotUseCaseProtocol,
        loadFileDiff: LoadFileDiffUseCaseProtocol,
        loadCommitDetails: LoadCommitDetailsUseCaseProtocol,
        stageFiles: StageFilesUseCaseProtocol,
        unstageFiles: UnstageFilesUseCaseProtocol,
        stageAllChanges: StageAllChangesUseCaseProtocol,
        discardFileChanges: DiscardFileChangesUseCaseProtocol,
        commitChanges: CommitChangesUseCaseProtocol,
        loadLastCommitMessage: LoadLastCommitMessageUseCaseProtocol,
        abortMerge: AbortMergeUseCaseProtocol,
        createBranch: CreateBranchUseCaseProtocol,
        checkoutBranch: CheckoutBranchUseCaseProtocol,
        deleteBranch: DeleteBranchUseCaseProtocol,
        mergeBranch: MergeBranchUseCaseProtocol,
        fetchRemotes: FetchRemotesUseCaseProtocol,
        pullBranch: PullBranchUseCaseProtocol,
        pushBranch: PushBranchUseCaseProtocol,
        stashChanges: StashChangesUseCaseProtocol,
        applyStash: ApplyStashUseCaseProtocol,
        dropStash: DropStashUseCaseProtocol,
        createTag: CreateTagUseCaseProtocol,
        deleteTag: DeleteTagUseCaseProtocol,
        runGitCommand: RunGitCommandUseCaseProtocol,
        loadCommitSummary: LoadCommitSummaryUseCaseProtocol,
        loadCommitFileDiff: LoadCommitFileDiffUseCaseProtocol,
        applyHunk: ApplyHunkUseCaseProtocol,
        revisions: RevisionDependencies,
        watchRepository: WatchRepositoryUseCaseProtocol,
        rebase: RebaseDependencies,
        remoteOptions: RemoteOptionsDependencies,
        exploration: ExplorationDependencies,
        conflicts: ConflictDependencies,
        tools: WorkingCopyToolsDependencies,
        workspace: WorkspaceDependencies,
        bisect: BisectDependencies,
        statistics: StatisticsDependencies,
        loadHistoryPage: LoadHistoryPageUseCaseProtocol,
        integration: IntegrationDependencies,
        commit: CommitDependencies,
        advanced: AdvancedDependencies,
        branchActions: BranchActionsDependencies,
        tagActions: TagActionsDependencies,
        sidebarOptions: SidebarOptionsDependencies,
        range: CommitRangeDependencies
    ) {
        self.loadSnapshot = loadSnapshot
        self.loadFileDiff = loadFileDiff
        self.loadCommitDetails = loadCommitDetails
        self.stageFiles = stageFiles
        self.unstageFiles = unstageFiles
        self.stageAllChanges = stageAllChanges
        self.discardFileChanges = discardFileChanges
        self.commitChanges = commitChanges
        self.loadLastCommitMessage = loadLastCommitMessage
        self.abortMerge = abortMerge
        self.createBranch = createBranch
        self.checkoutBranch = checkoutBranch
        self.deleteBranch = deleteBranch
        self.mergeBranch = mergeBranch
        self.fetchRemotes = fetchRemotes
        self.pullBranch = pullBranch
        self.pushBranch = pushBranch
        self.stashChanges = stashChanges
        self.applyStash = applyStash
        self.dropStash = dropStash
        self.createTag = createTag
        self.deleteTag = deleteTag
        self.runGitCommand = runGitCommand
        self.loadCommitSummary = loadCommitSummary
        self.loadCommitFileDiff = loadCommitFileDiff
        self.applyHunk = applyHunk
        self.revisions = revisions
        self.watchRepository = watchRepository
        self.rebase = rebase
        self.remoteOptions = remoteOptions
        self.exploration = exploration
        self.conflicts = conflicts
        self.tools = tools
        self.workspace = workspace
        self.bisect = bisect
        self.statistics = statistics
        self.loadHistoryPage = loadHistoryPage
        self.integration = integration
        self.commit = commit
        self.advanced = advanced
        self.branchActions = branchActions
        self.tagActions = tagActions
        self.sidebarOptions = sidebarOptions
        self.range = range
    }
}

extension RepositoryDependencies {
    func unstage(paths: [String], amending: Bool) async throws {
        if amending {
            try await commit.unstageFromAmend.execute(paths: paths)
        } else {
            try await unstageFiles.execute(paths: paths)
        }
    }
}
