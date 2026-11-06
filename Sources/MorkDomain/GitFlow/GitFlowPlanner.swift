import Foundation

public enum GitFlowPlanner {
    private static let forbidden = CharacterSet(charactersIn: " ~^:?*[\\\t\n")

    public static func plan(_ action: GitFlowAction, in context: GitFlowContext) throws -> [GitFlowStep] {
        switch action {
        case let .initialize(configuration):
            try initialize(configuration, context: context)
        case let .start(kind, name):
            try start(kind, name: name, context: context)
        case let .finish(kind, name):
            try finish(kind, name: name, context: context)
        }
    }

    public static func strip(_ branch: String, kind: GitFlowBranchKind, configuration: GitFlowConfiguration) -> String {
        let prefix = configuration.prefix(for: kind)
        return branch.hasPrefix(prefix) ? String(branch.dropFirst(prefix.count)) : branch
    }

    private static func initialize(_ configuration: GitFlowConfiguration, context: GitFlowContext) throws -> [GitFlowStep] {
        let main = try validName(configuration.mainBranch)
        let develop = try validName(configuration.developBranch)
        guard main != develop else { throw GitFlowError.sameMainAndDevelop }
        for (kind, prefix) in [("feature", configuration.featurePrefix), ("release", configuration.releasePrefix), ("hotfix", configuration.hotfixPrefix)] {
            guard !prefix.trimmingCharacters(in: .whitespaces).isEmpty else { throw GitFlowError.emptyPrefix(kind) }
            _ = try validName(prefix)
        }
        var steps: [GitFlowStep] = []
        if !context.hasCommits {
            steps.append(GitFlowStep(["symbolic-ref", "HEAD", "refs/heads/\(main)"], note: "Git Flow: the repository has no commits yet, so point HEAD at the unborn \(main) branch."))
            steps.append(GitFlowStep(["commit", "--allow-empty", "-m", "Initial commit"], note: "Git Flow: an empty first commit gives \(main) and \(develop) something to point at."))
        } else if !context.localBranches.contains(main) {
            throw GitFlowError.branchMissing(main)
        }
        if !context.localBranches.contains(develop) {
            steps.append(GitFlowStep(["branch", develop, main], note: "Git Flow: \(develop) is the integration branch. It starts at \(main); features branch off it and merge back into it."))
        }
        for entry in configuration.configEntries {
            steps.append(GitFlowStep(["config", "--local", entry.key, entry.value], note: "Git Flow: store the setting in .git/config under the same key the git-flow tool uses, so both understand this repository."))
        }
        if context.currentBranch != develop {
            steps.append(GitFlowStep(["switch", develop], note: "Git Flow: daily work happens on \(develop)."))
        }
        return steps
    }

    private static func start(_ kind: GitFlowBranchKind, name: String, context: GitFlowContext) throws -> [GitFlowStep] {
        guard let configuration = context.configuration else { throw GitFlowError.notInitialized }
        let branch = configuration.prefix(for: kind) + (try validName(name))
        guard !context.localBranches.contains(branch) else { throw GitFlowError.branchExists(branch) }
        let base = configuration.base(for: kind)
        guard context.localBranches.contains(base) else { throw GitFlowError.branchMissing(base) }
        let why = switch kind {
        case .feature: "a feature starts from \(base) and goes back into it when it is done"
        case .release: "a release branch freezes \(base) for final fixes before it goes to \(configuration.mainBranch)"
        case .hotfix: "a hotfix starts from \(base), the released code, so it can ship without unfinished work from \(configuration.developBranch)"
        }
        return [GitFlowStep(["switch", "-c", branch, base], note: "Git Flow: start \(kind.rawValue) \(branch); \(why).")]
    }

    private static func finish(_ kind: GitFlowBranchKind, name: String, context: GitFlowContext) throws -> [GitFlowStep] {
        guard let configuration = context.configuration else { throw GitFlowError.notInitialized }
        let short = try validName(strip(name, kind: kind, configuration: configuration))
        let branch = configuration.prefix(for: kind) + short
        guard context.localBranches.contains(branch) else { throw GitFlowError.branchMissing(branch) }
        let main = configuration.mainBranch
        let develop = configuration.developBranch
        let targets = kind == .feature ? [develop] : [main, develop]
        for target in targets where !context.localBranches.contains(target) {
            throw GitFlowError.branchMissing(target)
        }
        let tag = configuration.versionTagPrefix + short
        if kind.createsTag, context.tags.contains(tag) { throw GitFlowError.tagExists(tag) }
        var steps: [GitFlowStep] = []
        for target in targets {
            steps.append(GitFlowStep(["switch", target], note: "Git Flow: finish \(branch); go to \(target) to merge it there."))
            steps.append(GitFlowStep(["merge", "--no-ff", "--no-edit", branch], note: "Git Flow: --no-ff always makes a merge commit, so \(branch) stays visible as one unit in the history of \(target).", isMerge: true))
            if kind.createsTag, target == main {
                steps.append(GitFlowStep(["tag", "-a", tag, "-m", "\(kind.title) \(short)"], note: "Git Flow: tag the merge on \(main) as version \(tag); an annotated tag stores who tagged it, when, and a message."))
            }
        }
        steps.append(GitFlowStep(["branch", "-d", branch], note: "Git Flow: \(branch) is merged, so delete it; -d refuses if any of its commits would be lost."))
        return steps
    }

    private static func validName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GitFlowError.emptyName }
        guard trimmed.rangeOfCharacter(from: forbidden) == nil, !trimmed.contains(".."), !trimmed.hasPrefix("-"), !trimmed.hasSuffix(".lock"), !trimmed.hasPrefix("/") else {
            throw GitFlowError.invalidName(trimmed)
        }
        return trimmed
    }
}
