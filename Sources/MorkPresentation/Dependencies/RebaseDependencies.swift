import MorkDomain
import Foundation

public struct RebaseDependencies: Sendable {
    public let loadRebaseSteps: LoadRebaseStepsUseCaseProtocol
    public let runInteractiveRebase: RunInteractiveRebaseUseCaseProtocol
    public let rebaseBranch: RebaseBranchUseCaseProtocol
    public let continueRebase: ContinueRebaseUseCaseProtocol
    public let skipRebase: SkipRebaseUseCaseProtocol
    public let abortRebase: AbortRebaseUseCaseProtocol

    public init(
        loadRebaseSteps: LoadRebaseStepsUseCaseProtocol,
        runInteractiveRebase: RunInteractiveRebaseUseCaseProtocol,
        rebaseBranch: RebaseBranchUseCaseProtocol,
        continueRebase: ContinueRebaseUseCaseProtocol,
        skipRebase: SkipRebaseUseCaseProtocol,
        abortRebase: AbortRebaseUseCaseProtocol
    ) {
        self.loadRebaseSteps = loadRebaseSteps
        self.runInteractiveRebase = runInteractiveRebase
        self.rebaseBranch = rebaseBranch
        self.continueRebase = continueRebase
        self.skipRebase = skipRebase
        self.abortRebase = abortRebase
    }
}

public struct RemoteOptionsDependencies: Sendable {
    public let loadRemotes: LoadRemotesUseCaseProtocol
    public let loadPullMode: LoadPullModeUseCaseProtocol
    public let pullWithMode: PullBranchWithModeUseCaseProtocol
    public let pullWithOptions: PullBranchWithOptionsUseCaseProtocol
    public let loadPullAutostash: LoadPullAutostashUseCaseProtocol
    public let pushWithOptions: PushBranchWithOptionsUseCaseProtocol
    public let fetchWithOptions: FetchWithOptionsUseCaseProtocol
    public let pushTag: PushTagUseCaseProtocol

    public init(
        loadRemotes: LoadRemotesUseCaseProtocol,
        loadPullMode: LoadPullModeUseCaseProtocol,
        pullWithMode: PullBranchWithModeUseCaseProtocol,
        pullWithOptions: PullBranchWithOptionsUseCaseProtocol,
        loadPullAutostash: LoadPullAutostashUseCaseProtocol,
        pushWithOptions: PushBranchWithOptionsUseCaseProtocol,
        fetchWithOptions: FetchWithOptionsUseCaseProtocol,
        pushTag: PushTagUseCaseProtocol
    ) {
        self.loadRemotes = loadRemotes
        self.loadPullMode = loadPullMode
        self.pullWithMode = pullWithMode
        self.pullWithOptions = pullWithOptions
        self.loadPullAutostash = loadPullAutostash
        self.pushWithOptions = pushWithOptions
        self.fetchWithOptions = fetchWithOptions
        self.pushTag = pushTag
    }
}
