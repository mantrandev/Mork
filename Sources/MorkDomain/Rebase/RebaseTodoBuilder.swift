import Foundation

public enum RebaseTodoBuilder {
    public static func build(_ steps: [RebaseStep]) throws -> RebaseTodo {
        guard !steps.isEmpty else { throw RebaseError.nothingToRebase }
        let merges = steps.map(\.commit).filter(\.isMerge)
        guard merges.isEmpty else { throw RebaseError.mergeCommits(subjects: merges.map(\.subject)) }
        var hasKeptCommit = false
        var messages: [String: String] = [:]
        for step in steps {
            switch step.action {
            case .squash, .fixup:
                guard hasKeptCommit else { throw RebaseError.nothingToMeldInto(subject: step.commit.subject) }
            case .reword:
                let message = step.message.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !message.isEmpty else { throw RebaseError.emptyRewordMessage(subject: step.commit.subject) }
                messages[step.commit.hash] = message
                hasKeptCommit = true
            case .pick, .edit:
                hasKeptCommit = true
            case .drop:
                break
            }
        }
        return RebaseTodo(lines: steps.map { "\($0.action.rawValue) \($0.commit.hash) \($0.commit.subject)" }, messages: messages)
    }
}

public enum RebaseCommand {
    public static func interactive(onto base: RebaseBase, autostash: Bool, updateRefs: Bool = false) -> [String] {
        ["rebase", "-i"] + autostashFlag(autostash) + (updateRefs ? ["--update-refs"] : []) + [base.revision]
    }

    public static func onto(_ branch: Branch, autostash: Bool) -> [String] {
        ["rebase"] + autostashFlag(autostash) + [branch.name]
    }

    private static func autostashFlag(_ autostash: Bool) -> [String] {
        autostash ? ["--autostash"] : []
    }
}
