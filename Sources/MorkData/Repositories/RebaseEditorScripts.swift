import MorkDomain
import Foundation

struct RebaseEditorScripts: Sendable {
    static let messagesFolder = "mork-messages"
    static let editorName = "mork-rebase-editor.sh"

    private static let editorScript = """
    state=$(git rev-parse --git-path rebase-merge) || exit 0
    commit=$(tail -n 1 "$state/done" 2>/dev/null | cut -d ' ' -f 2)
    message="$state/\(messagesFolder)/$commit"
    if [ -n "$commit" ] && [ -f "$message" ]; then cat "$message" > "$1"; fi

    """

    private static let mergeUpdateRefs = """
    NR == FNR {
        if ($1 == "update-ref") refs[hash] = refs[hash] $0 "\\n"
        else if (NF > 1 && $1 !~ /^#/) hash = $2
        next
    }
    {
        print
        for (prefix in refs) if (prefix != "" && index($2, prefix) == 1) { printf "%s", refs[prefix]; delete refs[prefix] }
    }
    """

    let directory: URL

    func editorEnvironment() throws -> [String: String] {
        let editor = directory.appendingPathComponent(Self.editorName)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(Self.editorScript.utf8).write(to: editor, options: .atomic)
        return ["GIT_EDITOR": Self.command(running: editor)]
    }

    func writePlan(_ todo: RebaseTodo) throws -> URL {
        let plan = directory.appendingPathComponent("mork-rebase-\(UUID().uuidString)")
        let messages = plan.appendingPathComponent("messages")
        let todoFile = plan.appendingPathComponent("git-rebase-todo")
        try FileManager.default.createDirectory(at: messages, withIntermediateDirectories: true)
        try Data(todo.text.utf8).write(to: todoFile)
        for (hash, message) in todo.messages {
            try Data((message + "\n").utf8).write(to: messages.appendingPathComponent(hash))
        }
        let script = """
        awk \(ShellWords.quote(Self.mergeUpdateRefs)) "$1" \(ShellWords.quote(todoFile.path)) > "$1.mork" &&
        mv "$1.mork" "$1" &&
        rm -rf "$(dirname "$1")/\(Self.messagesFolder)" &&
        cp -R \(ShellWords.quote(messages.path)) "$(dirname "$1")/\(Self.messagesFolder)"

        """
        try Data(script.utf8).write(to: Self.sequenceEditor(in: plan))
        return plan
    }

    func environment(plan: URL) throws -> [String: String] {
        try editorEnvironment().merging(["GIT_SEQUENCE_EDITOR": Self.command(running: Self.sequenceEditor(in: plan))]) { _, new in new }
    }

    func remove(_ plan: URL) {
        try? FileManager.default.removeItem(at: plan)
    }

    private static func sequenceEditor(in plan: URL) -> URL {
        plan.appendingPathComponent("sequence-editor.sh")
    }

    private static func command(running script: URL) -> String {
        "sh " + ShellWords.quote(script.path)
    }
}
