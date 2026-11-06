import MorkDomain
import Foundation

extension RepositoryViewModel {
    static let leanWorkflow = "Lean Branching"

    public var leanBase: Branch? {
        LeanBranching.base(in: localBranches)
    }

    public var leanSyncTarget: String? {
        guard let base = leanBase, let current = currentBranch else { return nil }
        return LeanBranching.syncTarget(for: current, base: base)
    }

    public var canFinishLeanBranch: Bool {
        guard let base = leanBase, let current = currentBranch else { return false }
        return current.name != base.name
    }

    public func startLeanBranch(named name: String) async {
        guard let base = leanBase else { return }
        do {
            let steps = try LeanBranching.start(named: name.trimmingCharacters(in: .whitespacesAndNewlines), on: base, existing: localBranches.map(\.name))
            await runGitFlow(steps, workflow: Self.leanWorkflow)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func syncLeanBranch() async {
        guard let base = leanBase, let current = currentBranch else { return }
        await runGitFlow(LeanBranching.sync(current, base: base), workflow: Self.leanWorkflow)
    }

    public func planLeanFinish() async -> Result<[GitFlowStep], LeanFinishProblem> {
        guard let base = leanBase, let current = currentBranch else { return .failure(LeanFinishProblem(message: "Lean branching needs main, master or develop with a remote branch.")) }
        do {
            return .success(try await dependencies.advanced.flow.planLeanFinish.execute(current: current, base: base))
        } catch {
            return .failure(LeanFinishProblem(message: error.localizedDescription))
        }
    }

    public func finishLeanBranch(_ steps: [GitFlowStep]) async {
        await runGitFlow(steps, workflow: Self.leanWorkflow)
    }
}

public struct LeanFinishProblem: Error, Equatable, Sendable {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}
