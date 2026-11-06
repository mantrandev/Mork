import Foundation

public enum Lessons {
    private static let optionsWithValue: Set<String> = ["-c", "-C", "--git-dir", "--work-tree", "--namespace"]

    private static let globalOptions: [String: String] = [
        "--version": "Print the version of the git program in use. Features and defaults change between versions, so check it first when a command behaves differently than a tutorial says."
    ]

    static let commands: [String: String] = [
        "init": "Create a new repository: makes a .git folder that stores the whole history.",
        "clone": "Download a repository with its full history into a new folder, add the source as the remote origin, and check out its default branch.",
        "status": "List changed files. Column 1 = staging area (index), column 2 = working tree. ?? = file not tracked by Git.",
        "add": "Put changes into the staging area. The next commit contains only what is staged. In a conflict, git add marks the file as resolved: whatever is on disk, markers included, becomes the staged version.",
        "restore": "Restore files. --staged: take a file out of staging. --worktree: drop unstaged changes in the working tree.",
        "rm": "Remove files from the index. --cached: stop tracking only, keep the file on disk. In a conflict where one side deleted the file, git rm resolves the conflict by accepting the delete.",
        "clean": "Delete files Git does not track. -f is required so nothing is deleted by mistake.",
        "commit": "Save a snapshot of the staging area as a new commit that points to its parent. --amend replaces the last commit with a new one.",
        "log": "Show commit history. --graph draws branches with characters, --all includes every branch and remote. git log <branch> walks only the commits reachable from that one branch, which is how the sidebar's branch filter works.",
        "show": "Show details of an object: commit info and its patch. git show <commit>:<path> prints one file exactly as it was in that commit, and git show :0:<path> prints the staged version. During a conflict the index holds up to three versions of the file instead: :1:<path> the base, :2:<path> ours and :3:<path> theirs.",
        "diff": "Compare content. No flags: working tree vs index. --cached: index vs HEAD.",
        "branch": "Manage branches. A branch is just a named pointer to a commit. -d deletes a merged branch, -D forces the delete.",
        "switch": "Move to another branch. -c creates a new branch at HEAD. --track creates a local branch that follows a remote branch.",
        "checkout": "Older command that both switches branches and restores files. Newer Git splits it into switch and restore.",
        "merge": "Combine another branch's history into the current branch, possibly with a merge commit. --abort cancels an unfinished merge.",
        "rebase": "Replay your commits on top of a new base. History gets straighter but commit hashes change.",
        "cherry-pick": "Apply the changes of one specific commit onto the current branch.",
        "revert": "Create a new commit that undoes an older one. Safe for history that is already pushed.",
        "reset": "Move the current branch to another commit. --hard also overwrites the working tree.",
        "stash": "Put uncommitted changes aside to work on something else. push = save, apply/pop = bring back, drop = delete.",
        "tag": "Give a fixed name to a commit, usually for a release. -a creates an annotated tag with a message.",
        "fetch": "Download new commits and branches from a remote. Your local branches stay untouched. A refspec after the remote, like main or +refs/heads/*:refs/remotes/origin/*, picks which remote branches to download and where to store them; without one, git uses the remote's configured refspec.",
        "pull": "fetch, then integrate the remote branch into the current branch: merge by default (--no-rebase), replay your commits on top (--rebase), or only fast-forward (--ff-only).",
        "push": "Send local commits to a remote. --set-upstream remembers the remote branch so next time plain git push is enough.",
        "remote": "Manage the list of remotes (usually origin): short names for the URLs you fetch from and push to.",
        "worktree": "Check out more branches at the same time, each in its own folder. All worktrees share one repository (.git), so commits made in one are visible in the others.",
        "submodule": "Embed another repository inside this one at a fixed commit. The parent stores only the path, the URL (in .gitmodules) and the commit hash the submodule must be at.",
        "config": "Read or write Git settings: name, email, aliases...",
        "rev-parse": "Plumbing command: turns names (HEAD, branch) into hashes, or asks about the repository.",
        "for-each-ref": "Plumbing command: lists refs (branches, tags) in a custom format. The app uses it to read branches and tags.",
        "reflog": "Log of every HEAD move: commit, checkout, reset, rebase. A commit that no branch points to anymore, lost after reset --hard or a rebase, is still listed here for about 90 days: find it and create a branch at it to rescue it.",
        "blame": "Show, for every line of a file, the commit, author and date that last changed it.",
        "rev-list": "Plumbing command: list the hashes of commits reachable from the given refs. The app uses it to find commits by hash prefix and lost commits.",
        "apply": "Apply a patch. --cached changes only the staging area, --reverse undoes the patch. The app stages, unstages and discards single hunks or selected lines this way: it builds a small patch with only those lines and pipes it to git apply.",
        "am": "Apply patches from a mailbox file (made by git format-patch) as real commits, keeping their author, date and message. --abort cancels a failed git am and restores the branch.",
        "format-patch": "Turn commits into patch files in mailbox format, with author, date and message, ready to email or to apply elsewhere with git am.",
        "check-ignore": "Tell whether a path is ignored and which rule ignores it. Rules come from .gitignore files (committed, shared with everyone) and .git/info/exclude (local, never committed).",
        "credential": "Plumbing for https passwords: git credential fill asks each credential helper, then GIT_ASKPASS, for a username and password; approve tells the helpers to store them, reject to forget them.",
        "bisect": "Find the commit that introduced a bug with a binary search: each good or bad answer cuts the commits left to test in half, so 1,000 commits need only about 10 tests.",
        "merge-file": "Plumbing command: a three-way merge of three plain files, the same line merge git merge runs on each file. git merge-file <ours> <base> <theirs> writes the result, with conflict markers where both sides changed the same lines, into <ours>. Its exit code is the number of conflicts, so exit 3 means three conflict blocks, not an error. Mork feeds it the three index stages of a conflicted file to show the base of every conflict, even when merge.conflictStyle is not diff3.",
        "mergetool": "Open each conflicted file in a merge tool. Git writes three versions next to it: $BASE (the common ancestor), $LOCAL (ours, HEAD) and $REMOTE (theirs, the incoming change). The tool saves the result to $MERGED, the conflicted file itself, and git adds it as resolved when the tool succeeds.",
        "ls-tree": "List the files and folders of one folder in a commit, without checking anything out. Each line shows the mode (100644 file, 100755 executable, 120000 symlink, 040000 folder, 160000 submodule), the object type, its hash and its name. <commit>:<folder> picks a folder inside the commit.",
        "cat-file": "Plumbing command: read one object straight from the object database. -s prints its size in bytes, blob prints a file's raw bytes. <commit>:<path> names the file as it was in that commit.",
        "difftool": "Show a diff in an external tool instead of as text. It takes the same arguments as git diff, writes the old version of each file to $LOCAL and the new one to $REMOTE, then starts the tool once per file."
    ]

    private static let flags: [String: String] = [
        "--porcelain=v1": "stable output format meant for scripts",
        "-z": "separate entries with NUL so file names with spaces are read correctly",
        "--pretty=format:": "custom output format; %H = hash, %P = parents, %an = author, %ae = author email, %at = time, %D = refs, %s = subject",
        "--no-index": "compare any two files, even outside Git",
        "--ff-only": "allow fast-forward only, refuse if the histories have diverged",
        "--amend": "replace the last commit, which changes its hash",
        "--prune": "delete remote branches that were removed on the server",
        "--cached": "work on the staging area (index) instead of the working tree",
        "--reverse": "apply the patch backwards, which undoes it",
        "--name-status": "list changed files with a status letter: A added, M modified, D deleted, R renamed",
        "--diff-merges=first-parent": "for a merge commit, compare only with its first parent",
        "--progress": "print progress (counting, receiving, resolving objects) even when the output is not a terminal, so the app can show it live",
        "--literal-pathspecs": "treat every path as a plain file name, so characters like * or ? in it are not wildcards",
        "--check": "only test whether the patch applies cleanly; change nothing",
        "protocol.file.allow=always": "-c sets a config value for this one command; this one lets git clone from local folders, which it blocks for submodules by default to protect you from malicious repositories"
    ]

    static let actions: [String: [String: String]] = [
        "remote": [
            "add": "save a new remote name with its URL in .git/config; nothing is downloaded until you fetch",
            "rename": "rename the remote and all its remote-tracking branches; local branches that track it are updated too",
            "set-url": "change where the remote points; the name and its remote-tracking branches stay",
            "remove": "forget the remote: its remote-tracking branches (refs/remotes/<name>/*) are deleted and local branches that tracked it lose their upstream; nothing changes on the server",
            "prune": "delete remote-tracking branches whose branch no longer exists on the server"
        ],
        "worktree": [
            "list": "show every worktree: folder, checked-out commit, branch, and whether it is locked or prunable",
            "add": "create a new folder with its own working tree and index, checked out at a branch; a branch can be checked out in only one worktree at a time",
            "lock": "protect a worktree from being pruned or removed, for example when it lives on a removable drive",
            "unlock": "remove the lock so the worktree can be pruned or removed again",
            "remove": "delete the worktree folder and its administrative files in .git/worktrees; the branch and its commits stay",
            "prune": "clean up administrative files of worktrees whose folder was deleted by hand"
        ],
        "submodule": [
            "status": "list submodules with the commit they are at; - not initialized, + checked-out commit differs from the one recorded in the parent, U merge conflict",
            "update": "check out in each submodule the exact commit the parent repository records (detached HEAD), cloning it first if needed",
            "add": "clone a repository into a folder, record its URL in .gitmodules and stage the folder as a submodule entry (a commit pointer)",
            "sync": "copy the URLs from .gitmodules into .git/config, needed after a submodule's URL changed upstream"
        ],
        "bisect": [
            "start": "begin a bisect session; git remembers the branch you are on and waits for one bad and one good commit",
            "good": "the bug is not in this commit, so the first bad commit comes after it; git checks out the middle of what is left",
            "bad": "the bug is in this commit, so the first bad commit is this one or an earlier one; git checks out the middle of what is left",
            "skip": "this commit cannot be tested (it does not build, for example); git picks a nearby commit instead, and if only skipped commits remain it cannot name a single culprit",
            "reset": "end the bisect and check out the branch you were on when it started; the refs/bisect/* markers are deleted",
            "log": "print every good, bad and skip answer so far; the same text lives in .git/BISECT_LOG and can be replayed with git bisect replay"
        ],
        "stash": [
            "list": "show every saved stash, newest first as stash@{0}; it reads the reflog of refs/stash, so it accepts git log options such as --format, --grep or -S"
        ]
    ]

    static let subcommandFlags: [String: [String: String]] = [
        "log": [
            "--all": "start from every ref: all branches, remote-tracking branches and tags",
            "--exclude": "--exclude=<ref> leaves that ref out when the next --all, --branches or --remotes expands; the app uses it for branches you hid from the graph",
            "--grep": "only commits whose message matches the text",
            "--author": "only commits whose author name or email matches the text",
            "-i": "ignore upper and lower case in --grep and --author",
            "-F": "treat the --grep and --author text literally, not as a regular expression",
            "-S": "pickaxe: only commits that add or remove this exact text, so the number of times it appears changes",
            "-G": "only commits whose diff adds or removes a line matching this regular expression",
            "--first-parent": "follow only the first parent of each merge, so a merged branch collapses into its merge commit",
            "--follow": "keep following one file across renames",
            "-L": "-L<start>,<end>:<file> traces only those lines back through history: each commit that changed them, with a diff of just that range. It follows the lines when they move or the file is renamed",
            "--no-walk": "show only the given commits, without walking their parents",
            "--stdin": "read the commits to show from standard input, one per line, so any number of hashes fits in one command",
            "--no-show-signature": "do not print gpg or ssh-keygen verification output, even when log.showSignature is set",
            "--name-only": "list the paths each commit changed, without the diff",
            "--date=raw": "print dates as seconds since 1970 plus the author's time zone offset, so the app can count commits by the author's local hour"
        ],
        "diff": [
            "-U": "-U<n> shows n lines of unchanged context around each change instead of the default 3",
            "-w": "ignore whitespace when comparing lines, so indentation-only changes disappear from the diff"
        ],
        "show": [
            "-s": "suppress the diff; print only the commit information",
            "--no-show-signature": "do not print gpg or ssh-keygen verification output, even when log.showSignature is set",
            "-U": "-U<n> shows n lines of unchanged context around each change instead of the default 3",
            "-w": "ignore whitespace when comparing lines, so indentation-only changes disappear from the diff"
        ],
        "rev-parse": [
            "--git-path": "print where a file inside .git really lives; in a linked worktree info/exclude is shared with the main repository",
            "--show-toplevel": "print the root folder of the working tree",
            "--path-format=absolute": "print paths as absolute paths instead of relative to the current folder"
        ],
        "check-ignore": [
            "-v": "also print the ignore file, line number and pattern that matched",
            "--no-index": "check the rules even for files that are already tracked",
            "--stdin": "read the paths from standard input; with -z they are separated by NUL, so any file name is passed safely"
        ],
        "format-patch": [
            "--stdout": "print the patch instead of writing 0001-*.patch files, so the app can save it where you choose",
            "-1": "only the given commit"
        ],
        "reflog": [
            "--date=unix": "print the time of each entry as seconds since 1970 so the app can show it as a relative time"
        ],
        "ls-tree": [
            "-l": "also print the size of each file in bytes; folders show -"
        ],
        "cat-file": [
            "-s": "print only the size of the object in bytes, so the app can refuse very large files before reading them"
        ],
        "blame": [
            "--porcelain": "machine-readable output: a header for each line, with author, date and summary the first time a commit appears"
        ],
        "rev-list": [
            "--not": "exclude commits reachable from the refs that follow; with --all, keeps only commits no branch or tag can reach",
            "--bisect-vars": "print what git bisect would do next: bisect_nr is how many revisions are left to test, bisect_steps roughly how many tests that takes"
        ],
        "switch": [
            "--detach": "check out a commit instead of a branch (detached HEAD); new commits belong to no branch until you create one"
        ],
        "checkout": [
            "--ours": "in a conflict, put our version of the file (stage 2, from HEAD) on disk. During a rebase, ours is the branch you rebase onto",
            "--theirs": "in a conflict, put their version of the file (stage 3, the incoming change) on disk. During a rebase, theirs is your commit being replayed"
        ],
        "commit": [
            "--no-edit": "use the prepared message without opening an editor; to finish a merge this is the \"Merge branch ...\" text git saved in .git/MERGE_MSG"
        ],
        "reset": [
            "--soft": "move the branch only; the undone commits stay staged in the index",
            "--mixed": "move the branch and reset the index; the undone changes stay in the working tree as unstaged (default mode)",
            "--hard": "move the branch, the index and the working tree; uncommitted changes are lost"
        ],
        "cherry-pick": [
            "--continue": "commit the resolved conflict and go on with the cherry-pick",
            "--abort": "cancel the cherry-pick and return to the state before it started",
            "-m": "the commit is a merge; -m 1 copies its changes relative to the first parent (the branch it was merged into)"
        ],
        "rebase": [
            "-i": "interactive: git writes a todo list (pick, reword, squash, fixup, drop; one line per commit, oldest first) and opens it in GIT_SEQUENCE_EDITOR. Mork sets that editor to a script that writes the list you built, so git runs it without asking",
            "--autostash": "stash uncommitted changes before the rebase and apply them again when it finishes",
            "--continue": "commit the resolved conflict and go on with the next todo line",
            "--skip": "drop the commit that stopped the rebase and go on with the next todo line",
            "--abort": "cancel the rebase and put the branch back where it was before it started"
        ],
        "fetch": [
            "--all": "fetch from every remote, each with its configured refspec; it takes no remote name or refspec",
            "--tags": "also download every tag, even tags on commits outside the fetched branches"
        ],
        "pull": [
            "--rebase": "replay your local commits on top of the fetched branch instead of merging",
            "--no-rebase": "merge the fetched branch, even if pull.rebase is set in the config"
        ],
        "push": [
            "--delete": "delete the branch on the remote; your remote-tracking branch for it goes away too",
            "--force-with-lease": "overwrite the remote branch, but only if it still points where your remote-tracking branch says; refuses when someone else pushed in the meantime",
            "--tags": "also push every local tag"
        ],
        "remote": [
            "-v": "show each remote's fetch and push URL",
            "--push": "change only the URL used by git push; fetch keeps the normal URL"
        ],
        "worktree": [
            "--porcelain": "stable, machine-readable output, one attribute per line (worktree, HEAD, branch, locked, prunable)",
            "-b": "create a new branch with this name and check it out in the new worktree",
            "--reason": "note stored with the lock and shown by git worktree list",
            "--force": "remove the worktree even if it has uncommitted or untracked changes; those changes are lost"
        ],
        "submodule": [
            "--init": "first register submodules from .gitmodules that were never initialized, copying their URL into .git/config",
            "--recursive": "also go into submodules inside submodules"
        ],
        "branch": [
            "--set-upstream-to": "make the branch track this remote branch; git pull, git push and the ahead/behind counts then use it",
            "--unset-upstream": "stop tracking: the branch no longer has an upstream"
        ],
        "config": [
            "--global": "use your personal config file (~/.gitconfig or $GIT_CONFIG_GLOBAL), shared by every repository on this Mac",
            "--local": "use this repository's .git/config; a value here wins over the global one for this repository only",
            "--get": "print the value of one key; exit code 1 means the key is not set, which is not an error",
            "--unset": "delete the key, so a value from a wider scope (global) applies again",
            "--unset-all": "delete every value of this key",
            "-f": "read or write this file instead of .git/config",
            "--null": "end each entry with NUL so values with spaces or newlines are read correctly",
            "--get-regexp": "print every key that matches the regular expression, with its value",
            "--type=path": "read the value as a path: a leading ~/ becomes your home folder"
        ],
        "merge-file": [
            "-p": "print the merged result instead of overwriting the first file",
            "--diff3": "also write the base lines between ||||||| and ======= in every conflict, as merge.conflictStyle=diff3 does",
            "--zdiff3": "like --diff3, but lines both sides changed the same way stay outside the block, so the blocks start and end where the plain style puts them",
            "--no-diff3": "write plain conflicts with only ours and theirs, even when merge.conflictStyle is diff3 or zdiff3",
            "--diff-algorithm": "--diff-algorithm=histogram picks the line diff git merge itself uses since Git 2.34, so the result matches what git merge wrote into the file",
            "-L": "-L <name> sets the label written after a marker; given three times, it names ours, the base and theirs"
        ],
        "mergetool": [
            "--no-prompt": "start the tool right away instead of asking \"Hit return to start merge resolution tool\" first",
            "--tool": "--tool=<name> picks the tool for this run instead of merge.tool from the config"
        ],
        "difftool": [
            "--no-prompt": "start the tool right away instead of asking \"Launch '<tool>' [Y/n]?\" for every file",
            "--tool": "--tool=<name> picks the tool for this run instead of diff.tool from the config"
        ],
        "revert": [
            "--continue": "commit the resolved conflict and go on with the revert",
            "--abort": "cancel the revert and return to the state before it started",
            "--no-edit": "use the default \"Revert ...\" message without opening an editor",
            "-m": "the commit is a merge; -m 1 undoes what the merge brought in and keeps the first parent (the branch it was merged into)"
        ]
    ]

    private static let configNotes: [String: (title: String, note: String)] = [
        "mergetool.keepbackup": ("mergetool.keepBackup", "false stops git from leaving a <file>.orig copy of the conflicted file behind"),
        "mergetool.*.path": ("mergetool.<tool>.path", "where the tool's program lives, set with -c for this one command, so it works without installing the tool's command-line helper"),
        "mergetool.*.cmd": ("mergetool.<tool>.cmd", "the command git runs for a custom tool; it replaces $BASE, $LOCAL, $REMOTE and $MERGED with the file paths"),
        "mergetool.*.trustexitcode": ("mergetool.<tool>.trustExitCode", "true: the tool's exit code decides (0 means resolved). false: git checks whether the tool saved the file and asks you when it did not"),
        "difftool.*.path": ("difftool.<tool>.path", "where the tool's program lives, set with -c for this one command"),
        "difftool.*.cmd": ("difftool.<tool>.cmd", "the command git runs for a custom diff tool; it replaces $LOCAL and $REMOTE with the two versions"),
        "gpg.*.allowedsignersfile": ("gpg.ssh.allowedSignersFile", "the list of SSH keys you trust for signatures; without it git cannot check SSH signatures at all, so Mork points it at an empty file for this read and signed commits show as not verified instead of unsigned")
    ]

    public static let conflictMarkers = """
        Git could not merge some lines on its own, so it wrote both versions into the file between conflict markers:
        <<<<<<< ours: starts our version (HEAD, the branch you are on; during a rebase, the branch you rebase onto).
        ||||||| base: only with merge.conflictStyle=diff3 or zdiff3, the common ancestor both sides started from.
        =======: ends our version (or the base) and starts their version.
        >>>>>>> theirs: ends their version, the incoming change (the merged branch, the picked or reverted commit, or your commit being replayed in a rebase).
        Keep the lines you want, remove every marker, then git add the file to mark it resolved.
        """

    public static func subcommand(of arguments: [String]) -> String? {
        subcommandIndex(of: arguments).map { arguments[$0] }
    }

    public static func explain(_ arguments: [String]) -> String? {
        guard let index = subcommandIndex(of: arguments) else {
            return arguments.lazy.compactMap { globalOptions[$0] }.first
        }
        guard case let subcommand = arguments[index], var text = commands[subcommand] ?? advancedCommands[subcommand] ?? commitActionCommands[subcommand] else { return nil }
        if index + 1 < arguments.endIndex, case let action = arguments[index + 1], let note = actions[subcommand]?[action] ?? advancedActions[subcommand]?[action] {
            text += "\n\(subcommand) \(action): \(note)"
        }
        let flagNotes = flags.merging(subcommandFlags[subcommand] ?? [:]) { _, scoped in scoped }
            .filter { flag, _ in arguments.contains { matches($0, flag: flag) } }
            .map { "\($0.key): \($0.value)" }
        let notes = [
            flagNotes,
            configNotes(in: arguments[..<index]),
            commitNotes(arguments, subcommand: subcommand),
            advancedNotes(arguments, subcommand: subcommand),
            branchMenuNotes(arguments, subcommand: subcommand),
            commitActionNotes(arguments, subcommand: subcommand),
            conflictStageNotes(arguments, subcommand: subcommand)
        ].flatMap { $0 }.sorted()
        if !notes.isEmpty {
            text += "\n" + notes.joined(separator: "\n")
        }
        return text
    }

    private static func configNotes(in options: ArraySlice<String>) -> [String] {
        zip(options, options.dropFirst()).compactMap { option, value in
            guard option == "-c" else { return nil }
            let parts = (value.split(separator: "=", maxSplits: 1).first ?? "").lowercased().split(separator: ".", omittingEmptySubsequences: false)
            let key = parts.count == 3 ? "\(parts[0]).*.\(parts[2])" : parts.joined(separator: ".")
            return configNotes[key].map { "\($0.title): \($0.note)" }
        }
    }

    static func matches(_ argument: String, flag: String) -> Bool {
        guard argument.hasPrefix(flag) else { return false }
        guard argument.count > flag.count, flag.hasPrefix("--") else { return true }
        return argument.dropFirst(flag.count).first == "=" || flag.last == "=" || flag.last == ":"
    }

    private static func subcommandIndex(of arguments: [String]) -> Int? {
        var index = arguments.startIndex
        while index < arguments.endIndex {
            let argument = arguments[index]
            if optionsWithValue.contains(argument) {
                index += 2
            } else if argument.hasPrefix("-") {
                index += 1
            } else {
                return index
            }
        }
        return nil
    }
}
