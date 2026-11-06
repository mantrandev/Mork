import Foundation

extension Lessons {
    static let branchMenuFlags: [String: [String: String]] = [
        "branch": [
            "-m": "-m <old> <new> renames the branch; its reflog and upstream setting move with it, and a worktree that has it checked out follows the new name"
        ],
        "rev-list": [
            "--count": "print only how many commits there are; <a>..<b> counts the commits in b that a does not have, so 0 for <upstream>..<branch> means the branch can be fast-forwarded"
        ],
        "symbolic-ref": [
            "--short": "print the target as origin/main instead of refs/remotes/origin/main",
            "--quiet": "when the ref is missing or not symbolic, exit with 1 and print nothing instead of an error"
        ],
        "push": [
            "--set-upstream": "remember <remote>/<branch> as the upstream of the pushed branch, even when it is not the branch you are on"
        ]
    ]

    static let localFetchNote = "fetch . <src>:<dst>: the remote . is this repository itself, so git moves the local branch <dst> to <src> without checking it out. It refuses unless that is a fast-forward, and never touches a branch checked out in a worktree"
    static let branchStartPointNote = "branch <name> <start>: create the branch at <start> (a branch, tag or commit) and stay on the current branch"
    static let remoteHeadNote = "refs/remotes/<remote>/HEAD points at the remote's default branch; git clone sets it, git remote set-head <remote> --auto refreshes it"

    static func branchMenuNotes(_ arguments: [String], subcommand: String) -> [String] {
        var notes = (branchMenuFlags[subcommand] ?? [:])
            .filter { flag, _ in arguments.contains { matches($0, flag: flag) } }
            .map { "\($0.key): \($0.value)" }
        let operands = positionalArguments(after: subcommand, in: arguments)
        if subcommand == "fetch", operands.first == "." { notes.append(localFetchNote) }
        if subcommand == "branch", operands.count == 2, operands.count == arguments.count - 1 { notes.append(branchStartPointNote) }
        if subcommand == "symbolic-ref", operands.contains(where: { $0.hasPrefix("refs/remotes/") && $0.hasSuffix("/HEAD") }) { notes.append(remoteHeadNote) }
        return notes
    }

    private static func positionalArguments(after subcommand: String, in arguments: [String]) -> [String] {
        guard let index = arguments.firstIndex(of: subcommand) else { return [] }
        return arguments[(index + 1)...].filter { !$0.hasPrefix("-") }
    }
}
