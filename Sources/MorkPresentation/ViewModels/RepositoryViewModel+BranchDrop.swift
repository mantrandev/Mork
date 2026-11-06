import MorkDomain
import Foundation

public struct BranchDropRequest: Identifiable, Equatable, Sendable {
    public let source: Branch
    public let target: Branch
    public let options: [BranchDropOption]

    public var id: String { "\(source.fullName)->\(target.fullName)" }
    public var available: [BranchDropOption] { options.filter(\.isAvailable) }
    public var title: String { "Drop \(source.name) on \(target.name)" }

    public var message: String {
        options.map { option in
            "\(option.title): " + (option.blockedReason ?? option.commands.joined(separator: " && "))
        }.joined(separator: "\n")
    }
}

extension RepositoryViewModel {
    @discardableResult
    public func dropBranch(named sourceName: String, onto targetName: String) -> Bool {
        guard let source = localBranches.first(where: { $0.name == sourceName }),
              let target = localBranches.first(where: { $0.name == targetName }) else { return false }
        let options = branchDropOptions(source: source, target: target)
        guard !options.isEmpty else { return false }
        pendingBranchDrop = BranchDropRequest(source: source, target: target, options: options)
        return true
    }

    public func performBranchDrop(_ option: BranchDropOption) async {
        pendingBranchDrop = nil
        guard let source = localBranches.first(where: { $0.fullName == option.source.fullName }),
              let target = localBranches.first(where: { $0.fullName == option.target.fullName }),
              let fresh = branchDropOptions(source: source, target: target).first(where: { $0.action == option.action }) else { return }
        if let reason = fresh.blockedReason {
            errorMessage = reason
            return
        }
        let merged = Branch(name: source.name, fullName: source.fullName, isCurrent: false, upstream: source.upstream, track: source.track)
        await perform { dependencies in
            if let checkout = fresh.checkout {
                try await dependencies.checkoutBranch.execute(branch: checkout)
            }
            switch fresh.action {
            case .merge:
                try await dependencies.mergeBranch.execute(branch: merged)
            case .rebase:
                try await dependencies.rebase.rebaseBranch.execute(onto: target, current: source, autostash: false)
            }
        }
    }

    private func branchDropOptions(source: Branch, target: Branch) -> [BranchDropOption] {
        BranchDropPlanner.options(source: source, target: target, current: currentBranch, hasUncommittedChanges: hasUncommittedChanges, state: repositoryState)
    }
}
