import Foundation

public enum LeanBranchingError: LocalizedError, Equatable, Sendable {
    case onBase(String)
    case nothingToFinish(String, base: String)
    case baseNotInSync(String, remote: String)

    public var errorDescription: String? {
        switch self {
        case let .onBase(base):
            "You are on \(base). Finish merges a branch into \(base), so switch to the branch you want to finish."
        case let .nothingToFinish(branch, base):
            "\(branch) has no commits that \(base) does not already have."
        case let .baseNotInSync(base, remote):
            "\(base) differs from \(remote). Switch to \(base) and Sync it (or push it) before finishing a branch into it."
        }
    }
}

public enum LeanBranching {
    public static let baseNames = ["main", "master", "develop"]

    public static func base(in branches: [Branch]) -> Branch? {
        baseNames.lazy.compactMap { name in
            branches.first { !$0.isRemote && $0.name == name && $0.upstream != nil && !$0.isUpstreamGone }
        }.first
    }

    public static func start(named name: String, on base: Branch, existing: [String]) throws -> [GitFlowStep] {
        try BranchNameRules.validate(name, existing: existing)
        let startPoint = base.behind > 0 ? base.upstream ?? base.name : base.name
        return [GitFlowStep(["switch", "-c", name, startPoint], note: "Lean branching: start \(name) on \(startPoint), the newest of \(base.name) and its remote branch.")]
    }

    public static func syncTarget(for current: Branch, base: Branch) -> String {
        current.name == base.name ? base.upstream ?? base.name : base.name
    }

    public static func sync(_ current: Branch, base: Branch) -> [GitFlowStep] {
        let target = syncTarget(for: current, base: base)
        return [GitFlowStep(["rebase", "--autostash", target], note: "Lean branching: replay \(current.name) on top of \(target); --autostash stashes local changes first and puts them back after.")]
    }

    public static func finish(_ current: Branch, base: Branch, commitsAhead: Int) throws -> [GitFlowStep] {
        guard current.name != base.name else { throw LeanBranchingError.onBase(base.name) }
        guard commitsAhead > 0 else { throw LeanBranchingError.nothingToFinish(current.name, base: base.name) }
        guard base.ahead == 0, base.behind == 0 else { throw LeanBranchingError.baseNotInSync(base.name, remote: base.upstream ?? base.name) }
        let merge = commitsAhead == 1
            ? GitFlowStep(["merge", "--ff-only", current.name], note: "Lean branching: one commit moves \(base.name) forward without a merge commit.", isMerge: true)
            : GitFlowStep(["merge", "--no-ff", "--no-edit", current.name], note: "Lean branching: several commits get a merge commit, so \(base.name) shows them as one finished branch.", isMerge: true)
        return [GitFlowStep(["switch", base.name], note: "Lean branching: finish happens on \(base.name)."), merge]
    }
}

public protocol PlanLeanFinishUseCaseProtocol: Sendable {
    func execute(current: Branch, base: Branch) async throws -> [GitFlowStep]
}

public final class PlanLeanFinishUseCase: PlanLeanFinishUseCaseProtocol {
    private let branches: BranchActionsRepositoryProtocol

    public init(branches: BranchActionsRepositoryProtocol) {
        self.branches = branches
    }

    public func execute(current: Branch, base: Branch) async throws -> [GitFlowStep] {
        let ahead = try await branches.countCommits(in: current.name, missingFrom: base.name)
        return try LeanBranching.finish(current, base: base, commitsAhead: ahead)
    }
}
