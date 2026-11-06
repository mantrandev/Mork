import MorkData
import MorkDomain
import MorkPresentation
import Foundation

@MainActor
enum AppContainer {
    static func makeAppViewModel(
        defaults: UserDefaults = .standard,
        panels: FilePanelsProtocol = AppKitFilePanels(),
        folderPanel: FolderPanelProtocol = AppKitFolderPanel(),
        accountServices: AccountServices? = nil,
        integration: IntegrationServices = .standard()
    ) -> AppViewModel {
        integration.detectInBackground()
        let console = ConsoleViewModel(explainCommand: ExplainGitCommandUseCase())
        let services = accountServices ?? AccountServices.make(defaults: defaults, options: LaunchOptions(arguments: []))
        let makeExecutor = makeExecutorFactory(logger: console, services: services)
        let locator = RepositoryLocatorImpl(makeExecutor: makeExecutor)
        let recents = RecentRepositoriesStoreImpl(defaults: defaults)
        let cloner = RepositoryClonerImpl(makeExecutor: makeExecutor)
        let pullPreferences = PullPreferencesStoreImpl(defaults: defaults)
        let historyOptions = HistoryOptionsStoreImpl(defaults: defaults)
        let sidebarOptions = SidebarOptionsStoreImpl(defaults: defaults)
        let openTabs = RepositoryTabsStoreImpl(defaults: defaults)
        let folders = RepositoryFoldersStoreImpl(defaults: defaults)
        let inspector = RepositoryInspectorImpl { ProcessGitCommandExecutor(directory: $0) }
        let settingsStore = SettingsStoreImpl(defaults: defaults)
        let signingKeys = SigningKeyRepositoryImpl(sshDirectory: services.sshDirectory)
        let dependencies = AppDependencies(
            locateRepository: LocateRepositoryUseCase(locator: locator),
            initializeRepository: InitializeRepositoryUseCase(locator: locator),
            makeRepositoryDependencies: {
                makeRepositoryDependencies(
                    executor: makeExecutor($0),
                    repository: $0,
                    pullPreferences: pullPreferences,
                    historyOptions: historyOptions,
                    sidebarOptions: sidebarOptions,
                    panels: panels,
                    folderPanel: folderPanel,
                    settings: settingsStore,
                    diffOptions: settingsStore,
                    integration: integration,
                    signingKeys: signingKeys,
                    logger: console
                )
            },
            cloneRepository: CloneRepositoryUseCase(cloner: cloner),
            loadRecentRepositories: LoadRecentRepositoriesUseCase(store: recents),
            rememberRecentRepository: RememberRecentRepositoryUseCase(store: recents),
            clearRecentRepositories: ClearRecentRepositoriesUseCase(store: recents),
            tabs: RepositoryTabsDependencies(
                loadTabs: LoadRepositoryTabsUseCase(store: openTabs),
                saveTabs: SaveRepositoryTabsUseCase(store: openTabs),
                checkRepositoryExists: CheckRepositoryExistsUseCase(store: openTabs),
                loadWorkspaces: LoadWorkspacesUseCase(store: WorkspaceStoreImpl(defaults: defaults), tabs: openTabs),
                saveWorkspaces: SaveWorkspacesUseCase(store: WorkspaceStoreImpl(defaults: defaults), tabs: openTabs),
                loadTabAppearances: LoadTabAppearancesUseCase(store: TabAppearanceStoreImpl(defaults: defaults)),
                saveTabAppearances: SaveTabAppearancesUseCase(store: TabAppearanceStoreImpl(defaults: defaults))
            ),
            repositoryManager: RepositoryManagerDependencies(
                loadFolders: LoadRepositoryFoldersUseCase(store: folders),
                addFolder: AddRepositoryFolderUseCase(store: folders),
                removeFolder: RemoveRepositoryFolderUseCase(store: folders),
                scanFolders: ScanRepositoryFoldersUseCase(scanner: FileSystemRepositoryScannerImpl()),
                loadStatus: LoadRepositoryStatusUseCase(inspector: inspector),
                loadWorktrees: LoadRepositoryWorktreesUseCase(inspector: inspector),
                loadOverview: LoadRepositoryOverviewUseCase(inspector: inspector),
                locateMainRepository: LocateMainRepositoryUseCase(inspector: inspector),
                folderPanel: folderPanel
            ),
            settings: makeSettingsDependencies(
                store: settingsStore,
                executor: makeExecutor(FileManager.default.homeDirectoryForCurrentUser),
                integration: integration,
                signingKeys: signingKeys,
                customCommands: CustomCommandsStoreImpl(defaults: defaults)
            ),
            accounts: makeAccountsDependencies(services: services),
            ssh: makeSSHDependencies(services: services),
            loadAuthorAvatar: LoadAuthorAvatarUseCase(avatars: services.authorAvatars)
        )
        return AppViewModel(dependencies: dependencies, console: console, preferences: defaults)
    }

    nonisolated static func makeSettingsDependencies(
        store: SettingsRepositoryProtocol,
        executor: GitCommandExecuting,
        environment: [String: String] = [:],
        integration: IntegrationServices = .standard(),
        signingKeys: SigningKeyRepositoryProtocol = SigningKeyRepositoryImpl(),
        customCommands: CustomCommandsRepositoryProtocol = CustomCommandsStoreImpl(defaults: .standard),
        commandLineTool: CommandLineToolRepositoryProtocol = AppContainer.bundledCommandLineTool()
    ) -> SettingsDependencies {
        let config = GitConfigRepositoryImpl(executor: executor, environment: environment)
        return SettingsDependencies(
            loadSettings: LoadSettingsUseCase(store: store),
            saveSettings: SaveSettingsUseCase(store: store),
            loadGitInstallation: LoadGitInstallationUseCase(installation: GitInstallationRepositoryImpl(executor: executor)),
            loadGlobalIdentity: LoadGitIdentityUseCase(config: config, scope: .global),
            saveGlobalIdentity: SaveGitIdentityUseCase(config: config, scope: .global),
            integration: integration.settingsDependencies,
            signing: SigningSettingsDependencies(
                loadSettings: LoadSigningSettingsUseCase(config: config, scope: .global),
                saveSettings: SaveSigningSettingsUseCase(config: config, scope: .global),
                loadInherited: nil,
                loadKeys: LoadSigningKeysUseCase(keys: signingKeys)
            ),
            customCommands: CustomCommandsDependencies(
                loadCommands: LoadCustomCommandsUseCase(store: customCommands),
                saveCommands: SaveCustomCommandsUseCase(store: customCommands)
            ),
            loadCommandLineTool: LoadCommandLineToolStatusUseCase(tool: commandLineTool),
            installCommandLineTool: InstallCommandLineToolUseCase(tool: commandLineTool)
        )
    }

    nonisolated static func bundledCommandLineTool(bundle: Bundle = .main) -> CommandLineToolRepositoryProtocol {
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Mork").lowercased()
        return CommandLineToolRepositoryImpl.standard(script: bundle.resourceURL?.appendingPathComponent("mork"), name: name)
    }

    static func makeDefaults(for options: LaunchOptions) -> UserDefaults {
        guard let suite = options.defaultsSuite, let defaults = UserDefaults(suiteName: suite) else { return .standard }
        if options.resetsDefaults {
            defaults.removePersistentDomain(forName: suite)
            forgetWindowLayout(in: .standard)
        }
        if let file = options.settingsFile, let data = try? Data(contentsOf: file) {
            defaults.set(data, forKey: SettingsStoreImpl.key)
        }
        return defaults
    }

    nonisolated static func forgetWindowLayout(in defaults: UserDefaults) {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("NSWindow Frame ") || key.hasPrefix("NSSplitView Subview Frames ") {
            defaults.removeObject(forKey: key)
        }
    }

    nonisolated static func makeRepositoryDependencies(
        executor: GitToolCommandExecuting,
        repository: URL,
        pullPreferences: PullPreferencesRepositoryProtocol,
        historyOptions: HistoryOptionsRepositoryProtocol = HistoryOptionsStoreImpl(defaults: .standard),
        sidebarOptions: SidebarOptionsRepositoryProtocol = SidebarOptionsStoreImpl(defaults: .standard),
        panels: FilePanelsProtocol = AppKitFilePanels(),
        folderPanel: FolderPanelProtocol = AppKitFolderPanel(),
        settings: SettingsRepositoryProtocol? = nil,
        diffOptions: DiffOptionsProviding = DiffOptions.standard,
        configEnvironment: [String: String] = [:],
        integration: IntegrationServices = .standard(),
        signingKeys: SigningKeyRepositoryProtocol = SigningKeyRepositoryImpl(),
        logger: GitCommandLogging? = nil
    ) -> RepositoryDependencies {
        let workingCopy = WorkingCopyRepositoryImpl(executor: executor, diffOptions: diffOptions)
        let history = HistoryRepositoryImpl(executor: executor, diffOptions: diffOptions)
        let branches = BranchRepositoryImpl(executor: executor)
        let remote = RemoteRepositoryImpl(executor: executor)
        let stashes = StashRepositoryImpl(executor: executor)
        let tags = TagRepositoryImpl(executor: executor)
        let commands = GitCommandRepositoryImpl(executor: executor)
        let revisions = RevisionRepositoryImpl(executor: executor)
        let rebase = RebaseRepositoryImpl(executor: executor)
        let reflog = ReflogRepositoryImpl(executor: executor)
        let files = FileInspectionRepositoryImpl(executor: executor)
        let conflicts = ConflictRepositoryImpl(executor: executor, root: repository)
        let patches = PatchRepositoryImpl(executor: executor)
        let remoteManagement = RemoteManagementRepositoryImpl(executor: executor)
        let worktrees = WorktreeRepositoryImpl(executor: executor)
        let submodules = SubmoduleRepositoryImpl(executor: executor, root: repository)
        let bisect = BisectRepositoryImpl(executor: executor)
        let ignore = IgnoreRepositoryImpl(executor: executor)
        let config = GitConfigRepositoryImpl(executor: executor, environment: configEnvironment)
        let externalTools = ExternalToolRepositoryImpl(executor: executor, root: repository)
        let templates = CommitTemplateRepositoryImpl(executor: executor, root: repository, environment: configEnvironment)
        let blobs = BlobRepositoryImpl(executor: executor, root: repository)
        let signatures = CommitSignatureRepositoryImpl(executor: executor)
        let comparison = LocalChangesComparisonRepositoryImpl(executor: executor, diffOptions: diffOptions)
        let ranges = CommitRangeRepositoryImpl(executor: executor, diffOptions: diffOptions)
        return RepositoryDependencies(
            loadSnapshot: LoadRepositorySnapshotUseCase(
                workingCopy: workingCopy,
                history: history,
                branches: branches,
                stashes: stashes,
                tags: tags,
                remotes: remoteManagement,
                worktrees: worktrees,
                submodules: submodules,
                bisect: bisect
            ),
            loadFileDiff: LoadFileDiffUseCase(workingCopy: workingCopy),
            loadCommitDetails: LoadCommitDetailsUseCase(history: history),
            stageFiles: StageFilesUseCase(workingCopy: workingCopy),
            unstageFiles: UnstageFilesUseCase(workingCopy: workingCopy),
            stageAllChanges: StageAllChangesUseCase(workingCopy: workingCopy),
            discardFileChanges: DiscardFileChangesUseCase(workingCopy: workingCopy),
            commitChanges: CommitChangesUseCase(workingCopy: workingCopy, templates: templates),
            loadLastCommitMessage: LoadLastCommitMessageUseCase(workingCopy: workingCopy),
            abortMerge: AbortMergeUseCase(workingCopy: workingCopy),
            createBranch: CreateBranchUseCase(branches: branches),
            checkoutBranch: CheckoutBranchUseCase(branches: branches),
            deleteBranch: DeleteBranchUseCase(branches: branches, actions: BranchActionsRepositoryImpl(executor: executor)),
            mergeBranch: MergeBranchUseCase(branches: branches),
            fetchRemotes: FetchRemotesUseCase(remote: remote),
            pullBranch: PullBranchUseCase(remote: remote),
            pushBranch: PushBranchUseCase(remote: remote),
            stashChanges: StashChangesUseCase(stashes: stashes, workingCopy: workingCopy),
            applyStash: ApplyStashUseCase(stashes: stashes),
            dropStash: DropStashUseCase(stashes: stashes),
            createTag: CreateTagUseCase(tags: tags),
            deleteTag: DeleteTagUseCase(tags: tags),
            runGitCommand: RunGitCommandUseCase(commands: commands),
            loadCommitSummary: LoadCommitSummaryUseCase(history: history, signatures: signatures),
            loadCommitFileDiff: LoadCommitFileDiffUseCase(history: history),
            applyHunk: ApplyHunkUseCase(workingCopy: workingCopy),
            revisions: RevisionDependencies(
                checkoutCommit: CheckoutCommitUseCase(revisions: revisions),
                createBranchAtCommit: CreateBranchAtCommitUseCase(revisions: revisions),
                createTagAtCommit: CreateTagAtCommitUseCase(revisions: revisions),
                cherryPickCommit: CherryPickCommitUseCase(revisions: revisions, workingCopy: workingCopy),
                revertCommit: RevertCommitUseCase(revisions: revisions, workingCopy: workingCopy),
                resetCurrentBranch: ResetCurrentBranchUseCase(revisions: revisions, workingCopy: workingCopy),
                continueOperation: ContinueOperationUseCase(revisions: revisions, workingCopy: workingCopy),
                abortOperation: AbortOperationUseCase(revisions: revisions, workingCopy: workingCopy)
            ),
            watchRepository: WatchRepositoryUseCase(watcher: FSEventsRepositoryWatcher()),
            rebase: RebaseDependencies(
                loadRebaseSteps: LoadRebaseStepsUseCase(rebase: rebase, workingCopy: workingCopy),
                runInteractiveRebase: RunInteractiveRebaseUseCase(rebase: rebase, workingCopy: workingCopy, branches: BranchActionsRepositoryImpl(executor: executor)),
                rebaseBranch: RebaseBranchUseCase(rebase: rebase, workingCopy: workingCopy),
                continueRebase: ContinueRebaseUseCase(rebase: rebase, workingCopy: workingCopy),
                skipRebase: SkipRebaseUseCase(rebase: rebase, workingCopy: workingCopy),
                abortRebase: AbortRebaseUseCase(rebase: rebase, workingCopy: workingCopy)
            ),
            remoteOptions: RemoteOptionsDependencies(
                loadRemotes: LoadRemotesUseCase(remote: remote),
                loadPullMode: LoadPullModeUseCase(preferences: pullPreferences, repository: repository, settings: settings),
                pullWithMode: PullBranchWithModeUseCase(remote: remote, preferences: pullPreferences, repository: repository),
                pullWithOptions: PullBranchWithOptionsUseCase(remote: remote, preferences: pullPreferences, repository: repository),
                loadPullAutostash: LoadPullAutostashUseCase(preferences: pullPreferences, repository: repository),
                pushWithOptions: PushBranchWithOptionsUseCase(remote: remote),
                fetchWithOptions: FetchWithOptionsUseCase(remote: remote),
                pushTag: PushTagUseCase(remote: remote)
            ),
            exploration: ExplorationDependencies(
                searchCommits: SearchCommitsUseCase(search: history),
                loadCommit: LoadCommitUseCase(search: history),
                loadReflog: LoadReflogUseCase(reflog: reflog),
                loadFileHistory: LoadFileHistoryUseCase(files: files),
                blameFile: BlameFileUseCase(files: files),
                loadLineHistory: LoadLineHistoryUseCase(lines: LineHistoryRepositoryImpl(executor: executor)),
                loadImageDiff: LoadImageDiffUseCase(blobs: blobs),
                loadHistoryOptions: LoadHistoryOptionsUseCase(store: historyOptions),
                saveHistoryOptions: SaveHistoryOptionsUseCase(store: historyOptions),
                tree: CommitTreeDependencies(
                    loadTreeEntries: LoadTreeEntriesUseCase(tree: CommitTreeRepositoryImpl(executor: executor)),
                    loadFileAtRevision: LoadFileAtRevisionUseCase(blobs: blobs),
                    saveFileAtRevision: SaveFileAtRevisionUseCase(blobs: blobs),
                    panels: panels
                ),
                compare: LocalChangesComparisonDependencies(
                    loadComparison: LoadLocalChangesComparisonUseCase(comparison: comparison),
                    loadDiff: LoadLocalChangesDiffUseCase(comparison: comparison)
                )
            ),
            conflicts: ConflictDependencies(
                loadConflict: LoadConflictUseCase(conflicts: conflicts),
                resolveConflictFile: ResolveConflictFileUseCase(conflicts: conflicts),
                saveConflictText: SaveConflictTextUseCase(conflicts: conflicts),
                markConflictResolved: MarkConflictResolvedUseCase(conflicts: conflicts),
                concludeMerge: ConcludeMergeUseCase(conflicts: conflicts, workingCopy: workingCopy)
            ),
            tools: WorkingCopyToolsDependencies(
                applyLines: ApplyLinesUseCase(workingCopy: workingCopy),
                addIgnoreRule: AddIgnoreRuleUseCase(ignore: ignore),
                loadPatchPreview: LoadPatchPreviewUseCase(patches: patches),
                checkPatch: CheckPatchUseCase(patches: patches),
                applyPatch: ApplyPatchUseCase(patches: patches),
                createPatch: CreatePatchUseCase(patches: patches),
                loadIgnoredFiles: LoadIgnoredFilesUseCase(workingCopy: workingCopy),
                stageIgnoredFiles: StageIgnoredFilesUseCase(workingCopy: workingCopy),
                panels: panels
            ),
            workspace: WorkspaceDependencies(
                remotes: RemoteManagementDependencies(
                    addRemote: AddRemoteUseCase(remotes: remoteManagement),
                    editRemote: EditRemoteUseCase(remotes: remoteManagement),
                    removeRemote: RemoveRemoteUseCase(remotes: remoteManagement),
                    fetchRemote: FetchRemoteUseCase(remotes: remoteManagement),
                    pruneRemote: PruneRemoteUseCase(remotes: remoteManagement),
                    deleteRemoteBranch: DeleteRemoteBranchUseCase(remotes: remoteManagement, branches: BranchActionsRepositoryImpl(executor: executor)),
                    setUpstream: SetUpstreamUseCase(remotes: remoteManagement),
                    unsetUpstream: UnsetUpstreamUseCase(remotes: remoteManagement)
                ),
                worktrees: WorktreeDependencies(
                    addWorktree: AddWorktreeUseCase(worktrees: worktrees),
                    removeWorktree: RemoveWorktreeUseCase(worktrees: worktrees),
                    lockWorktree: LockWorktreeUseCase(worktrees: worktrees),
                    unlockWorktree: UnlockWorktreeUseCase(worktrees: worktrees),
                    pruneWorktrees: PruneWorktreesUseCase(worktrees: worktrees)
                ),
                submodules: SubmoduleDependencies(
                    updateSubmodules: UpdateSubmodulesUseCase(submodules: submodules),
                    addSubmodule: AddSubmoduleUseCase(submodules: submodules),
                    syncSubmodules: SyncSubmodulesUseCase(submodules: submodules)
                ),
                settings: RepositorySettingsDependencies(
                    loadLocalIdentity: LoadGitIdentityUseCase(config: config, scope: .local),
                    saveLocalIdentity: SaveGitIdentityUseCase(config: config, scope: .local),
                    loadGlobalIdentity: LoadGitIdentityUseCase(config: config, scope: .global),
                    loadIgnoreFile: LoadIgnoreFileUseCase(ignore: ignore),
                    saveIgnoreFile: SaveIgnoreFileUseCase(ignore: ignore),
                    loadLocalCommitTemplate: LoadGitConfigValueUseCase(config: config, key: .commitTemplate, scope: .local),
                    loadGlobalCommitTemplate: LoadGitConfigValueUseCase(config: config, key: .commitTemplate, scope: .global),
                    saveLocalCommitTemplate: SaveGitConfigValueUseCase(config: config, key: .commitTemplate, scope: .local),
                    signing: SigningSettingsDependencies(
                        loadSettings: LoadSigningSettingsUseCase(config: config, scope: .local),
                        saveSettings: SaveSigningSettingsUseCase(config: config, scope: .local),
                        loadInherited: LoadSigningSettingsUseCase(config: config, scope: .global),
                        loadKeys: LoadSigningKeysUseCase(keys: signingKeys)
                    )
                )
            ),
            bisect: BisectDependencies(
                startBisect: StartBisectUseCase(bisect: bisect, workingCopy: workingCopy),
                markBisectCommit: MarkBisectCommitUseCase(bisect: bisect, workingCopy: workingCopy),
                resetBisect: ResetBisectUseCase(bisect: bisect),
                loadBisectLog: LoadBisectLogUseCase(bisect: bisect)
            ),
            statistics: StatisticsDependencies(
                loadStatistics: LoadRepositoryStatisticsUseCase(statistics: StatisticsRepositoryImpl(executor: executor))
            ),
            loadHistoryPage: LoadHistoryPageUseCase(history: history),
            integration: IntegrationDependencies(
                openConflictInMergeTool: OpenConflictInMergeToolUseCase(resolve: integration.resolveTool, tools: externalTools, workingCopy: workingCopy),
                openInDiffTool: OpenInDiffToolUseCase(resolve: integration.resolveTool, tools: externalTools),
                openInApp: integration.openInApp
            ),
            commit: CommitDependencies(
                loadCommitTemplate: LoadCommitTemplateUseCase(templates: templates),
                loadCommitSignatures: LoadCommitSignaturesUseCase(signatures: signatures),
                loadCommitMessages: LoadCommitMessagesUseCase(messages: history),
                runCustomCommand: RunCustomCommandUseCase(git: commands, shell: ShellCommandRepositoryImpl(root: repository, logger: logger))
            ),
            advanced: makeAdvancedDependencies(executor: executor, repository: repository, diffOptions: diffOptions),
            branchActions: makeBranchActionsDependencies(executor: executor, workingCopy: workingCopy, remote: remote, remoteManagement: remoteManagement),
            tagActions: TagActionsDependencies(loadDetails: LoadTagDetailsUseCase(tags: tags), merge: MergeTagUseCase(tags: tags, workingCopy: workingCopy), rebase: RebaseTagUseCase(tags: tags, workingCopy: workingCopy), deleteFromRemotes: DeleteTagFromRemotesUseCase(tags: tags)),
            sidebarOptions: SidebarOptionsDependencies(load: LoadSidebarOptionsUseCase(store: sidebarOptions), save: SaveSidebarOptionsUseCase(store: sidebarOptions)),
            range: CommitRangeDependencies(
                cherryPickCommits: CherryPickCommitsUseCase(revisions: revisions, workingCopy: workingCopy),
                revertCommits: RevertCommitsUseCase(revisions: revisions, workingCopy: workingCopy),
                checkRange: CheckCommitRangeUseCase(ranges: ranges),
                loadChanges: LoadCommitRangeChangesUseCase(ranges: ranges),
                loadDiff: LoadCommitRangeDiffUseCase(ranges: ranges),
                savePatch: SaveCommitRangePatchUseCase(ranges: ranges),
                folderPanel: folderPanel
            )
        )
    }
}
