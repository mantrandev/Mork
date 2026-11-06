import Foundation

public enum BranchDropAction: Hashable, Sendable {
    case merge
    case rebase
}

public struct BranchDropOption: Identifiable, Hashable, Sendable {
    public let action: BranchDropAction
    public let source: Branch
    public let target: Branch
    public let checkout: Branch?
    public let blockedReason: String?

    public init(action: BranchDropAction, source: Branch, target: Branch, checkout: Branch?, blockedReason: String?) {
        self.action = action
        self.source = source
        self.target = target
        self.checkout = checkout
        self.blockedReason = blockedReason
    }

    public var id: BranchDropAction { action }
    public var isAvailable: Bool { blockedReason == nil }

    public var title: String {
        switch action {
        case .merge: "Merge \(source.name) into \(target.name)"
        case .rebase: "Rebase \(source.name) onto \(target.name)"
        }
    }

    public var commands: [String] {
        let run = switch action {
        case .merge: "git merge \(source.name)"
        case .rebase: "git rebase \(target.name)"
        }
        return (checkout.map { ["git switch \($0.name)"] } ?? []) + [run]
    }
}

public enum BranchDropPlanner {
    public static func options(source: Branch, target: Branch, current: Branch?, hasUncommittedChanges: Bool, state: RepositoryState) -> [BranchDropOption] {
        guard !source.isRemote, !target.isRemote, source.fullName != target.fullName else { return [] }
        let busy = state == .clean ? nil : "Finish or abort the \(describe(state)) first."
        let mergeCheckout = target.isCurrent ? nil : target
        let rebaseCheckout = source.isCurrent ? nil : source
        let mergeBlocked = busy ?? (mergeCheckout != nil && hasUncommittedChanges ? "Commit or stash your changes before switching to \(target.name)." : nil)
        let rebaseBlocked = busy ?? (hasUncommittedChanges ? "Commit or stash your changes before rebasing \(source.name)." : nil)
        return [
            BranchDropOption(action: .merge, source: source, target: target, checkout: mergeCheckout, blockedReason: mergeBlocked),
            BranchDropOption(action: .rebase, source: source, target: target, checkout: rebaseCheckout, blockedReason: rebaseBlocked)
        ]
    }

    private static func describe(_ state: RepositoryState) -> String {
        switch state {
        case .clean: "operation"
        case .merging: "merge"
        case .rebasing: "rebase"
        case .cherryPicking: "cherry-pick"
        case .reverting: "revert"
        }
    }
}
