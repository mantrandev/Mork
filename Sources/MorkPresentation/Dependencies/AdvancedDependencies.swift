import MorkDomain
import Foundation

public struct LFSDependencies: Sendable {
    public let loadInstallation: LoadLFSInstallationUseCaseProtocol
    public let initialize: InitializeLFSUseCaseProtocol
    public let loadPatterns: LoadLFSPatternsUseCaseProtocol
    public let track: TrackLFSPatternUseCaseProtocol
    public let untrack: UntrackLFSPatternUseCaseProtocol
    public let transfer: TransferLFSObjectsUseCaseProtocol
    public let loadFiles: LoadLFSFilesUseCaseProtocol

    public init(
        loadInstallation: LoadLFSInstallationUseCaseProtocol,
        initialize: InitializeLFSUseCaseProtocol,
        loadPatterns: LoadLFSPatternsUseCaseProtocol,
        track: TrackLFSPatternUseCaseProtocol,
        untrack: UntrackLFSPatternUseCaseProtocol,
        transfer: TransferLFSObjectsUseCaseProtocol,
        loadFiles: LoadLFSFilesUseCaseProtocol
    ) {
        self.loadInstallation = loadInstallation
        self.initialize = initialize
        self.loadPatterns = loadPatterns
        self.track = track
        self.untrack = untrack
        self.transfer = transfer
        self.loadFiles = loadFiles
    }
}

public struct GitFlowDependencies: Sendable {
    public let loadContext: LoadGitFlowContextUseCaseProtocol
    public let runSteps: RunGitFlowStepsUseCaseProtocol
    public let planLeanFinish: PlanLeanFinishUseCaseProtocol

    public init(loadContext: LoadGitFlowContextUseCaseProtocol, runSteps: RunGitFlowStepsUseCaseProtocol, planLeanFinish: PlanLeanFinishUseCaseProtocol) {
        self.loadContext = loadContext
        self.runSteps = runSteps
        self.planLeanFinish = planLeanFinish
    }
}

public struct AdvancedDependencies: Sendable {
    public let lfs: LFSDependencies
    public let flow: GitFlowDependencies
    public let loadTreemap: LoadTreemapUseCaseProtocol
    public let runBenchmark: RunPerformanceBenchmarkUseCaseProtocol

    public init(lfs: LFSDependencies, flow: GitFlowDependencies, loadTreemap: LoadTreemapUseCaseProtocol, runBenchmark: RunPerformanceBenchmarkUseCaseProtocol) {
        self.lfs = lfs
        self.flow = flow
        self.loadTreemap = loadTreemap
        self.runBenchmark = runBenchmark
    }
}
