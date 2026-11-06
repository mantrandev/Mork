import Foundation

extension Lessons {
    static let advancedCommands: [String: String] = [
        "lfs": "Git LFS (Large File Storage), an add-on installed separately (brew install git-lfs). Files matching a tracked pattern are stored on the LFS server; the repository itself only keeps a small pointer file with the object's sha256 and size, so clones stay small.",
        "symbolic-ref": "Read or change a symbolic ref, a ref that names another ref. HEAD is one: it usually holds refs/heads/<branch>. Pointing HEAD at a branch that has no commits yet makes the next commit start that branch.",
        "check-attr": "Print the attributes that .gitattributes files give to each path. filter=lfs on a path means Git LFS stores that file, so Mork marks it with an LFS badge. It works even when git-lfs is not installed."
    ]

    static let advancedActions: [String: [String: String]] = [
        "lfs": [
            "version": "print the installed git-lfs version; git answers \"'lfs' is not a git command\" when it is not installed",
            "install": "set up the LFS clean and smudge filters and the pre-push hook that uploads LFS objects; --local writes them to this repository's .git/config only",
            "track": "add a pattern with filter=lfs diff=lfs merge=lfs -text to .gitattributes; commit .gitattributes so everyone stores those files in LFS. Files committed before keep their old history",
            "untrack": "remove the pattern from .gitattributes; files already stored in LFS stay pointers until you add them again",
            "fetch": "download the LFS objects of the current branch into .git/lfs without changing files in the working tree",
            "pull": "git lfs fetch, then replace the pointer files in the working tree with the real file contents (checkout)",
            "ls-files": "list the files in the current commit that are stored in LFS"
        ]
    ]

    static let advancedFlags: [String: [String: String]] = [
        "lfs": [
            "--local": "change only this repository, not your global git config"
        ],
        "merge": [
            "--no-ff": "always create a merge commit, even when git could just move the branch forward; the merged branch then stays visible as one unit in the history",
            "--no-edit": "use git's default message \"Merge branch '<name>' into <branch>\" without opening an editor"
        ],
        "tag": [
            "-a": "make an annotated tag: a real object with the tagger, date and message (given with -m, so no editor opens), which git describe and releases use"
        ],
        "branch": [
            "-d": "delete the branch only if it is merged into the current branch (or its upstream), so no commit is lost; -D deletes anyway"
        ],
        "switch": [
            "-c": "-c <new> <start> creates the branch at <start> and switches to it in one step"
        ],
        "ls-tree": [
            "-r": "go into every subfolder, so each file of the commit is listed once with its full path; with -l the treemap reads every file's size from this one command"
        ],
        "commit": [
            "--allow-empty": "make a commit even though nothing changed; Git Flow uses it to start an empty repository"
        ],
        "check-attr": [
            "--stdin": "read the paths from standard input; with -z they are separated by NUL, so any file name is passed safely",
            "--source": "--source=<commit> reads .gitattributes as they were in that commit instead of the working tree"
        ]
    ]

    static let gitFlowConfigKeys: [String: String] = [
        "gitflow.branch.master": "gitflow.branch.master: the production branch; every commit on it is a release. The git-flow tool reads the same key",
        "gitflow.branch.develop": "gitflow.branch.develop: the integration branch where finished features are merged",
        "gitflow.prefix.feature": "gitflow.prefix.feature: name prefix of feature branches, for example feature/",
        "gitflow.prefix.release": "gitflow.prefix.release: name prefix of release branches, for example release/",
        "gitflow.prefix.hotfix": "gitflow.prefix.hotfix: name prefix of hotfix branches, for example hotfix/",
        "gitflow.prefix.support": "gitflow.prefix.support: name prefix of support branches for old versions; stored so the git-flow tool sees the repository as initialized",
        "gitflow.prefix.versiontag": "gitflow.prefix.versiontag: text put in front of the version when a release or hotfix is tagged, for example v; empty means the tag is just the version"
    ]

    static func advancedNotes(_ arguments: [String], subcommand: String) -> [String] {
        let flags = (advancedFlags[subcommand] ?? [:])
            .filter { flag, _ in arguments.contains { matches($0, flag: flag) } }
            .map { "\($0.key): \($0.value)" }
        guard subcommand == "config" else { return flags }
        return flags + Set(arguments.map { $0.lowercased() }).compactMap { gitFlowConfigKeys[$0] }
    }
}
