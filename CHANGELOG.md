# Changelog

## v0.0.6 (2026-11-11)

### History

- A local branch and its remote with the same name share one badge, marked with a cloud.
- Long branch names shrink in the middle instead of folding into +N. Only badges that still do not fit fold into +N.
- The commit subject starts right after the badges, with no gap.

## v0.0.5 (2026-11-11)

### History

- A commit with several tags shows one badge with the count, such as "14 tags", instead of one tag name followed by +N. A commit with one tag still shows its name.

## v0.0.4 (2026-11-11)

### History

- Hover a tag badge with +N, or a +N badge, to see every name in a popover. Click the badge to keep the popover open. The tooltip from v0.0.3 did not appear.
- Right-click a tag in the popover for the same actions as in the sidebar: checkout, push, merge, rebase, delete and more.

## v0.0.3 (2026-11-11)

### History

- A commit with many tags shows them as one badge: the newest version, then +N. The tooltip lists every tag.
- Branch badges come before tags, and badges never push the commit subject out of the row.
- The file header bar no longer collapses and grows back when you select another branch or commit.

### Memory

- Preloaded commit diffs are capped at 4 MB of text, so browsing History with Show Entire File on no longer grows memory by hundreds of MB.
- Background tabs drop their caches, and every tab drops them when macOS runs low on memory.
- The interactive rebase sheet keeps diffs of the selected commit only.

## v0.0.2 (2026-11-10)

### Interactive rebase

- Selecting a commit lists its changed files. Each file expands to its diff, and Expand All loads every diff of the commit.
- A new Changes tab shows the commit like the Changes tab in the main window: file list with filter and tree mode, and the diff of the selected file. The sheet remembers the last tab.
- The selected step stays gray when the list has focus.

### Diffs

- Changes has the same file header bar as History.
- New toggles: show invisible characters, wrap long lines and show the entire file.
- Side-by-side diffs mark a leading tab or space.
- Narrow headers fold the diff options into one menu.

### Fetch and pull

- Pull runs first, then fetches all remotes in the background.
- Auto-fetch runs when you return to a tab or to the app and the interval has passed.
- A failed background fetch no longer opens a dialog. It still shows in the Git Console.

### Branches

- New-branch dialogs remember the check out choice.

## v0.0.1 (2026-11-07)

The first public release of Mork, a native Git client for macOS that teaches Git as you use it.

### Learn as you work

- Every action runs the real `git` command. The Git Console shows the command, its output and what each flag means.
- Dialogs show the exact command their button will run.

### Everyday Git

- Stage, unstage or discard a file, folder, hunk or single line, with image diffs.
- Commit, amend and sign commits.
- Browse history with a commit graph, search commits, and see file history, line history, blame and reflog.
- Create, merge, rebase, cherry-pick, revert and reset branches, and reorder or squash commits with interactive rebase.
- Fetch, pull and push, manage remotes, and create, push and delete tags.
- Fix conflicts in a 3-way or 2-way view inside the app.

### Windows and tools

- Several windows and tabs, workspaces and Quick Launch.
- Bisect, statistics, a file size treemap, Git Flow, Git LFS, custom commands and a built-in terminal.
- GitHub, GitLab, Bitbucket and Gitea accounts in the Keychain, and SSH key management.
- The `mork` command opens a repository from the terminal.
