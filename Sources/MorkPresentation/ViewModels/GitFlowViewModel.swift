import MorkDomain
import Foundation
import Observation

public enum GitFlowMode: Hashable, Sendable {
    case initialize
    case start(GitFlowBranchKind)
    case finish(GitFlowBranchKind)

    public var title: String {
        switch self {
        case .initialize: "Initialize Git Flow"
        case let .start(kind): "Start \(kind.title)"
        case let .finish(kind): "Finish \(kind.title)"
        }
    }

    public var summary: String {
        switch self {
        case .initialize:
            "Git Flow keeps released code on a production branch and daily work on a development branch. Mork runs plain git commands and stores the branch names under gitflow.* in .git/config, like the git-flow tool."
        case .start(.feature):
            "A feature branch starts from the development branch and goes back into it when it is done."
        case .start(.release):
            "A release branch freezes the development branch for final fixes before it ships."
        case .start(.hotfix):
            "A hotfix branch starts from the production branch, so an urgent fix can ship without unfinished work."
        case .finish(.feature):
            "The feature is merged into the development branch with a merge commit, then its branch is deleted."
        case .finish(.release), .finish(.hotfix):
            "The branch is merged into the production branch and tagged, merged into the development branch, then deleted."
        }
    }
}

@MainActor
@Observable
public final class GitFlowViewModel: Identifiable {
    public let id = UUID()
    public private(set) var mode: GitFlowMode
    public private(set) var context: Loadable<GitFlowContext> = .idle
    public private(set) var steps: [GitFlowStep] = []
    public private(set) var problem: GitFlowError?
    public private(set) var isRunning = false
    public var configuration = GitFlowConfiguration.standard {
        didSet { if configuration != oldValue { updatePlan() } }
    }
    public var name = "" {
        didSet { if name != oldValue { updatePlan() } }
    }
    public var finishBranch = "" {
        didSet { if finishBranch != oldValue { updatePlan() } }
    }

    private let loadContext: LoadGitFlowContextUseCaseProtocol
    private let run: @MainActor ([GitFlowStep]) async -> Bool

    public init(mode: GitFlowMode, loadContext: LoadGitFlowContextUseCaseProtocol, run: @escaping @MainActor ([GitFlowStep]) async -> Bool) {
        self.mode = mode
        self.loadContext = loadContext
        self.run = run
    }

    public var loadedContext: GitFlowContext? {
        if case let .loaded(context) = context { return context }
        return nil
    }

    public var needsInitialization: Bool {
        guard mode != .initialize, let context = loadedContext else { return false }
        return !context.isInitialized
    }

    public var finishCandidates: [String] {
        guard case let .finish(kind) = mode else { return [] }
        return loadedContext?.branches(of: kind) ?? []
    }

    public var prefix: String {
        switch mode {
        case let .start(kind), let .finish(kind): loadedContext?.configuration?.prefix(for: kind) ?? ""
        case .initialize: ""
        }
    }

    public var canRun: Bool { !isRunning && problem == nil && !steps.isEmpty && !needsInitialization }

    public func load() async {
        context = .loading
        do {
            let loaded = try await loadContext.execute()
            configuration = loaded.configuration ?? Self.suggestedConfiguration(for: loaded)
            context = .loaded(loaded)
            if case let .finish(kind) = mode {
                let candidates = loaded.branches(of: kind)
                finishBranch = loaded.currentBranch.flatMap { candidates.contains($0) ? $0 : nil } ?? candidates.first ?? ""
            }
            updatePlan()
        } catch {
            context = .failed(error.localizedDescription)
        }
    }

    public func initializeInstead() {
        mode = .initialize
        updatePlan()
    }

    @discardableResult
    public func confirm() async -> Bool {
        guard canRun else { return false }
        isRunning = true
        defer { isRunning = false }
        return await run(steps)
    }

    static func suggestedConfiguration(for context: GitFlowContext) -> GitFlowConfiguration {
        var configuration = GitFlowConfiguration.standard
        let branches = context.localBranches
        if !branches.contains("main") {
            if branches.contains("master") {
                configuration.mainBranch = "master"
            } else if let current = context.currentBranch, current != configuration.developBranch {
                configuration.mainBranch = current
            }
        }
        return configuration
    }

    private func updatePlan() {
        guard let context = loadedContext else {
            steps = []
            problem = nil
            return
        }
        let action: GitFlowAction = switch mode {
        case .initialize: .initialize(configuration)
        case let .start(kind): .start(kind, name: name)
        case let .finish(kind): .finish(kind, name: finishBranch)
        }
        do {
            steps = try GitFlowPlanner.plan(action, in: context)
            problem = nil
        } catch let error as GitFlowError {
            steps = []
            problem = error
        } catch {
            steps = []
            problem = nil
        }
    }
}
