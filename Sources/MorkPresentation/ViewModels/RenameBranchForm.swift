import MorkDomain
import Foundation

public struct RenameBranchForm: Equatable, Sendable {
    public let branch: Branch
    public let existingNames: [String]
    public let remote: String?
    public var name: String
    public var alsoRenameOnRemote = false

    public init(branch: Branch, localBranches: [Branch], remotes: [String]) {
        self.branch = branch
        existingNames = localBranches.map(\.name).filter { $0 != branch.name }
        name = branch.name
        let tracked = PushForm.defaultRemote(for: branch, in: remotes)
        remote = !branch.isUpstreamGone && branch.upstream == "\(tracked)/\(branch.name)" ? tracked : nil
    }

    public var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    public var isUnchanged: Bool { trimmedName == branch.name }

    public var problem: String? {
        guard !isUnchanged else { return nil }
        return BranchNameRules.problem(with: trimmedName, existing: existingNames)?.errorDescription
    }

    public var canRename: Bool { !isUnchanged && problem == nil }
    public var renamesOnRemote: Bool { alsoRenameOnRemote && remote != nil }
    public var remoteForRename: String? { renamesOnRemote ? remote : nil }

    public var commands: [String] {
        let new = canRename ? trimmedName : "<new name>"
        var lines = [["git", "branch", "-m", branch.name, new]]
        if renamesOnRemote, let remote {
            lines.append(["git", "push", "--set-upstream", remote, new])
            lines.append(["git", "push", remote, "--delete", branch.name])
        }
        return lines.map { $0.map(ShellWords.quote).joined(separator: " ") }
    }
}
