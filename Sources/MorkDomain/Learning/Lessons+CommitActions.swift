import Foundation

extension Lessons {
    static let commitActionCommands: [String: String] = [
        "ls-files": "List the files git knows about in the index. --others lists untracked files instead, the ones git status shows with ??.",
        "merge-base": "Find the best common ancestor of commits."
    ]

    static let commitActionFlags: [String: [String: String]] = [
        "cherry-pick": [
            "--no-commit": "apply the commit's changes to the index and working tree but do not commit, so you can review, edit or combine them and commit yourself",
            "-x": "append \"(cherry picked from commit <hash>)\" to the message, so the copy records where it came from"
        ],
        "revert": [
            "--no-commit": "undo the commit's changes in the index and working tree but do not commit; git stays in the revert state until you commit or run git revert --continue"
        ],
        "merge-base": [
            "--is-ancestor": "print nothing and answer with the exit code only: 0 when the first commit is an ancestor of the second, 1 when it is not"
        ],
        "format-patch": [
            "-o": "write one numbered file per commit (0001-<subject>.patch, 0002-…) into this folder",
            "--root": "start at the first commit of the history, so the root commit gets a patch too"
        ],
        "diff": [
            "-M": "detect renames: a file that was moved, and maybe changed a little, shows as one rename (R) instead of a delete plus an add"
        ],
        "ls-files": [
            "--others": "list untracked files: files in the working tree that are not in the index",
            "--exclude-standard": "leave out files ignored by .gitignore, .git/info/exclude and your global excludes file"
        ]
    ]

    static let diffAgainstCommit = "git diff <commit>: compare that commit with the files on disk, staged and unstaged changes together"
    static let diffBetweenCommits = "git diff <old> <new>: compare two commits directly. <commit>^ is the parent of a commit, so git diff A^ B shows the changes of A through B as one diff"
    static let emptyTreeNote = "\(CommitRange.emptyTree): the empty tree, which git always knows. Comparing with it shows the whole content of the newer commit, so a range that starts at the root commit still has a base"
    static let severalCommitsNote = "several commits: git applies them one at a time in the order given and stops at the first conflict; resolve it, then --continue goes on with the rest or --abort undoes them all"
    static let patchRangeNote = "A^..B: the commits reachable from B but not from the parent of A, which is A through B"

    static func commitActionNotes(_ arguments: [String], subcommand: String) -> [String] {
        let flags = (commitActionFlags[subcommand] ?? [:])
            .filter { flag, _ in arguments.contains { matches($0, flag: flag) } }
            .map { "\($0.key): \($0.value)" }
        return flags
            + (comparesCommitWithWorkingTree(arguments, subcommand: subcommand) ? [diffAgainstCommit] : [])
            + rangeNotes(arguments, subcommand: subcommand)
    }

    private static func rangeNotes(_ arguments: [String], subcommand: String) -> [String] {
        guard let start = arguments.firstIndex(of: subcommand) else { return [] }
        let words = revisions(after: start, in: arguments)
        switch subcommand {
        case "cherry-pick", "revert":
            return words.count > 1 ? [severalCommitsNote] : []
        case "diff":
            guard words.count == 2 else { return [] }
            return [diffBetweenCommits] + (words.contains(CommitRange.emptyTree) ? [emptyTreeNote] : [])
        case "format-patch":
            return words.contains { $0.contains("..") } ? [patchRangeNote] : []
        default:
            return []
        }
    }

    private static func revisions(after start: Int, in arguments: [String]) -> [String] {
        var words: [String] = []
        var index = start + 1
        while index < arguments.endIndex, arguments[index] != "--" {
            let argument = arguments[index]
            if argument == "-m" || argument == "-o" {
                index += 2
                continue
            }
            if !argument.hasPrefix("-") { words.append(argument) }
            index += 1
        }
        return words
    }

    private static func comparesCommitWithWorkingTree(_ arguments: [String], subcommand: String) -> Bool {
        guard subcommand == "diff", let start = arguments.firstIndex(of: subcommand) else { return false }
        let options = arguments[(start + 1)...].prefix { $0 != "--" }
        guard !options.contains("--cached"), !options.contains("--staged"), !options.contains("--no-index") else { return false }
        return options.filter { !$0.hasPrefix("-") }.count == 1
    }
}
