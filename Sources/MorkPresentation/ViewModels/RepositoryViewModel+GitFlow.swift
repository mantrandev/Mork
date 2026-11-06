import MorkDomain
import Foundation

extension RepositoryViewModel {
    public func showGitFlow(_ mode: GitFlowMode) async {
        let session = GitFlowViewModel(mode: mode, loadContext: dependencies.advanced.flow.loadContext) { [weak self] steps in
            await self?.runGitFlow(steps) ?? false
        }
        advanced.gitFlow = session
        await session.load()
    }

    public func closeGitFlow() {
        advanced.gitFlow = nil
    }

    @discardableResult
    public func runGitFlow(_ steps: [GitFlowStep], workflow: String = "Git Flow") async -> Bool {
        var outcome: GitFlowOutcome?
        let succeeded = await perform { outcome = try await $0.advanced.flow.runSteps.execute(steps) }
        guard succeeded, let outcome else { return false }
        if case let .stoppedOnConflict(step, remaining) = outcome {
            pane = .changes
            let rest = remaining.isEmpty ? "" : "\n\nThen run the remaining steps in the Git Console:\n" + remaining.map(\.commandLine).joined(separator: "\n")
            notice = Notice(
                title: "\(workflow) Stopped on a Conflict",
                message: "\(step.commandLine) stopped because both branches changed the same lines. Resolve the conflicts in Changes and commit the merge, or abort it from the banner.\(rest)"
            )
        }
        return true
    }
}
