import MorkDomain
import Foundation

enum DialogCommands {
    static let literalPathspecs = "--literal-pathspecs"

    static func line(_ arguments: [String]) -> String {
        (["git"] + arguments).map { isPlaceholder($0) ? $0 : ShellWords.quote($0) }.joined(separator: " ")
    }

    private static func isPlaceholder(_ word: String) -> Bool {
        word.count > 2 && word.hasPrefix("<") && word.hasSuffix(">") && !word.dropFirst().dropLast().contains { $0 == "<" || $0 == ">" || $0 == " " }
    }

    static func discard(_ changes: [FileChange]) -> [DialogCommandLine] {
        let untracked = changes.filter(\.isUntracked)
        let tracked = changes.filter { !$0.isUntracked }
        var lines: [DialogCommandLine] = []
        if !tracked.isEmpty {
            lines.append(group(["restore", "--worktree"], paths: tracked.map(\.path)))
        }
        if !untracked.isEmpty {
            lines.append(group(["clean", "-f"], paths: untracked.map(\.path)))
        }
        return lines
    }

    static func discardPatch(lines: Bool) -> DialogCommandLine {
        DialogCommandLine(text: line(["apply", "--reverse", "-"]), note: lines ? "selected lines on stdin" : "hunk on stdin")
    }

    static func deleteTags(_ names: [String]) -> DialogCommandLine {
        guard names.count > 1, let first = names.first else {
            return DialogCommandLine(text: line(["tag", "-d"] + names))
        }
        return DialogCommandLine(text: line(["tag", "-d", first]), note: "runs for \(names.count) tags")
    }

    static func removeConflictedFile(_ path: String) -> DialogCommandLine {
        DialogCommandLine(text: line([literalPathspecs, "rm", "--quiet", "--", path]))
    }

    static func markResolved(_ path: String) -> DialogCommandLine {
        DialogCommandLine(text: line([literalPathspecs, "add", "--", path]))
    }

    static func reset(_ mode: ResetMode, to hash: String) -> String {
        line(["reset", mode.flag, hash])
    }

    static func removeRemote(_ name: String) -> DialogCommandLine {
        DialogCommandLine(text: line(["remote", "remove", name]))
    }

    static func deleteRemoteBranch(remote: String, branch: String) -> DialogCommandLine {
        DialogCommandLine(text: line(["push", remote, "--delete", branch]))
    }

    static func removeWorktree(_ path: String, force: Bool) -> DialogCommandLine {
        DialogCommandLine(text: line(["worktree", "remove"] + (force ? ["--force"] : []) + [path]))
    }

    static func createBranch(name: String, startPoint: String, checkout: Bool) -> String {
        line(checkout ? ["switch", "-c", name, startPoint] : ["branch", name, startPoint])
    }

    static func addRemote(name: String, url: String) -> String {
        let name = name.trimmingCharacters(in: .whitespaces)
        let url = url.trimmingCharacters(in: .whitespaces)
        return line(["remote", "add", name.isEmpty ? "<name>" : name, url.isEmpty ? "<url>" : url])
    }

    static func createTag(name: String, message: String, revision: String?) -> String {
        let target = revision.map { [$0] } ?? []
        return line((message.isEmpty ? ["tag", name] : ["tag", "-a", name, "-m", message]) + target)
    }

    static func pushTag(_ name: String, to remotes: [String]) -> DialogCommandLine? {
        perRemote(remotes, unit: "remotes") { ["push", $0, "refs/tags/\(name)"] }
    }

    static func deleteRemoteTag(_ name: String, from remotes: [String]) -> DialogCommandLine? {
        perRemote(remotes, unit: "remotes") { ["push", $0, ":refs/tags/\(name)"] }
    }

    static func addWorktree(_ form: WorktreeForm) -> String {
        if let request = form.request { return line(request.arguments) }
        let path = form.path.trimmingCharacters(in: .whitespacesAndNewlines)
        let branch = form.selectedBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        let start = form.startPoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = branch.isEmpty ? "<branch>" : branch
        let checkout: WorktreeCheckout = form.mode == .newBranch ? .newBranch(name, startPoint: start.isEmpty ? nil : start) : .existingBranch(name)
        return line(AddWorktreeRequest(path: path.isEmpty ? "<path>" : path, checkout: checkout).arguments)
    }

    static func lockWorktree(_ path: String, reason: String) -> String {
        let reason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        return line(["worktree", "lock"] + (reason.isEmpty ? [] : ["--reason", reason]) + [path])
    }

    static func addSubmodule(url: String, path: String) -> String {
        let url = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = path.trimmingCharacters(in: .whitespacesAndNewlines)
        return line(["submodule", "add", "--", url.isEmpty ? "<url>" : url, path.isEmpty ? "<path>" : path])
    }

    static let updateSubmodules = line(["submodule", "update", "--init", "--recursive", "--progress"])

    static func stash(message: String) -> String {
        let message = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return line(["stash", "push", "--include-untracked"] + (message.isEmpty ? [] : ["-m", message]))
    }

    static func lfsTrack(_ pattern: String) -> String {
        let pattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        return line(["lfs", "track", pattern.isEmpty ? "<pattern>" : pattern])
    }

    static func lfsUntrack(_ pattern: String) -> String {
        line(["lfs", "untrack", pattern])
    }

    static func lfsTransfer(_ transfer: LFSTransfer) -> String {
        line(["lfs", transfer.rawValue])
    }

    static let bisectLog = line(["bisect", "log"])

    static func fileHistory(_ path: String) -> String {
        line([literalPathspecs, "log", "--follow", "-M", "--", path])
    }

    static func blame(_ path: String, at commit: Commit?) -> String {
        line(["blame", "--porcelain"] + (commit.map { [$0.shortHash] } ?? []) + ["--", path])
    }

    static func lineHistory(_ request: LineHistoryRequest) -> String {
        line(["log", "-L\(request.range):\(request.path)", request.revision.count == 40 ? String(request.revision.prefix(7)) : request.revision])
    }

    private static func perRemote(_ remotes: [String], unit: String, _ arguments: (String) -> [String]) -> DialogCommandLine? {
        guard let first = remotes.first else { return nil }
        return DialogCommandLine(text: line(arguments(first)), note: remotes.count > 1 ? "runs for \(remotes.count) \(unit)" : DialogCommandLine.confirmNote)
    }

    private static func group(_ command: [String], paths: [String]) -> DialogCommandLine {
        guard paths.count > 1, let first = paths.first else {
            return DialogCommandLine(text: line([literalPathspecs] + command + ["--"] + paths))
        }
        return DialogCommandLine(text: line([literalPathspecs] + command + ["--", first]), note: "runs for \(paths.count) files")
    }
}

struct ErrorReport: Equatable {
    struct Line: Equatable {
        let text: String
        let isError: Bool

        init(_ text: String) {
            self.text = text
            let trimmed = text.drop { $0 == " " }
            isError = trimmed.hasPrefix("!") || trimmed.hasPrefix("error:") || trimmed.hasPrefix("fatal:")
        }
    }

    static let fallbackTitle = "Git Error"

    let title: String
    let summary: String
    let command: String?
    let output: [Line]

    init(message: String) {
        let lines = message.components(separatedBy: "\n")
        guard lines.count >= 2, let exitCode = Self.exitCode(lines[1]) else {
            title = Self.fallbackTitle
            summary = message
            command = nil
            output = []
            return
        }
        let command = lines[0]
        var rest = Array(lines.dropFirst(2))
        while rest.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { rest.removeLast() }
        self.command = command
        output = rest.map(Line.init)
        let name = Self.subcommand(of: command)
        title = name.map { "\($0.prefix(1).uppercased())\($0.dropFirst()) failed" } ?? "Command failed"
        summary = "\(name.map { "git \($0)" } ?? "The command") stopped with exit code \(exitCode). Git's output below says why; fix that, then run it again."
    }

    static func hiddenFilesNote(_ paths: [String]) -> String {
        let names = paths.joined(separator: ", ")
        let subject = paths.count == 1 ? "\(names) is" : "\(names) are"
        return "\(subject) marked skip-worktree or assume-unchanged, so Git hides the local changes and the Changes list looks clean. Unhide to see the changes, then commit, stash or discard them and run the command again."
    }

    private static func exitCode(_ line: String) -> Int32? {
        guard line.hasPrefix("exit ") else { return nil }
        return Int32(line.dropFirst("exit ".count))
    }

    private static func subcommand(of command: String) -> String? {
        let words = command.split(separator: " ").map(String.init)
        guard words.first == "git" else { return nil }
        var index = 1
        while index < words.count, words[index].hasPrefix("-") {
            index += words[index] == "-c" || words[index] == "-C" ? 2 : 1
        }
        return index < words.count ? words[index] : nil
    }
}

extension MorkConfirmation {
    static func deleteConflictedFile(_ path: String, identifier: String, perform: @escaping () -> Void) -> MorkConfirmation {
        MorkConfirmation(
            kind: .destructive,
            title: "Delete \(path)?",
            message: "Deleting the file resolves the conflict. Both sides keep their version in their own commit, so you can restore it from history later.",
            commands: [DialogCommands.removeConflictedFile(path)],
            actions: [DialogAction(title: "Delete File", isDestructive: true, identifier: identifier, perform: perform)]
        )
    }
}
