import Foundation

public enum RebaseAction: String, CaseIterable, Sendable {
    case pick
    case edit
    case reword
    case squash
    case fixup
    case drop

    public var meldsIntoPrevious: Bool { self == .squash || self == .fixup }

    public var abbreviation: Character { rawValue.first ?? "p" }

    public init?(abbreviation: Character) {
        guard let action = Self.allCases.first(where: { $0.abbreviation == Character(abbreviation.lowercased()) }) else { return nil }
        self = action
    }

    public var explanation: String {
        switch self {
        case .pick: "use the commit as it is"
        case .edit: "use the commit, but stop so you can amend it"
        case .reword: "use the commit, but change its message"
        case .squash: "meld into the previous commit and keep both messages"
        case .fixup: "meld into the previous commit and discard this message"
        case .drop: "remove the commit and its changes"
        }
    }
}

public struct RebaseStep: Identifiable, Hashable, Sendable {
    public let commit: Commit
    public let originalMessage: String
    public var action: RebaseAction
    public var message: String

    public init(commit: Commit, originalMessage: String) {
        self.commit = commit
        self.originalMessage = originalMessage
        action = .pick
        message = originalMessage
    }

    public var id: String { commit.hash }
}

public enum RebaseBase: Hashable, Sendable {
    case commit(Commit)
    case branch(Branch)

    public var revision: String {
        switch self {
        case let .commit(commit): commit.hash
        case let .branch(branch): branch.name
        }
    }

    public var title: String {
        switch self {
        case let .commit(commit): commit.shortHash
        case let .branch(branch): branch.name
        }
    }
}

public struct RebaseRange: Equatable, Sendable {
    public let steps: [RebaseStep]
    public let skippedMerges: [Commit]

    public init(steps: [RebaseStep], skippedMerges: [Commit]) {
        self.steps = steps
        self.skippedMerges = skippedMerges
    }
}

public struct InteractiveRebaseOptions: Equatable, Sendable {
    public var autostash: Bool
    public var updateRefs: Bool
    public var backupBranch: String?

    public init(autostash: Bool, updateRefs: Bool = false, backupBranch: String? = nil) {
        self.autostash = autostash
        self.updateRefs = updateRefs
        self.backupBranch = backupBranch
    }
}

public enum RebaseBackup {
    public static func branchName(for branch: String, at date: Date) -> String {
        let format = Date.VerbatimFormatStyle(
            format: "\(year: .defaultDigits)\(month: .twoDigits)\(day: .twoDigits)-\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased))\(minute: .twoDigits)\(second: .twoDigits)",
            timeZone: .current,
            calendar: Calendar(identifier: .gregorian)
        )
        return "\(branch)-backup-\(date.formatted(format))"
    }
}

public struct RebaseTodo: Equatable, Sendable {
    public let lines: [String]
    public let messages: [String: String]

    public init(lines: [String], messages: [String: String]) {
        self.lines = lines
        self.messages = messages
    }

    public var text: String { lines.map { $0 + "\n" }.joined() }
}

public enum RebaseError: LocalizedError, Sendable, Equatable {
    case nothingToRebase
    case uncommittedChanges
    case mergeCommits(subjects: [String])
    case emptyRewordMessage(subject: String)
    case nothingToMeldInto(subject: String)

    public var errorDescription: String? {
        switch self {
        case .nothingToRebase:
            "There are no commits between this commit and HEAD, so there is nothing to rebase."
        case .uncommittedChanges:
            "You have uncommitted changes. Commit or stash them first, or choose Stash and Rebase: git rebase --autostash stashes them, rebases, then applies them again."
        case let .mergeCommits(subjects):
            "The range contains merge commits: \(subjects.joined(separator: ", ")). An interactive rebase replays commits one by one and would flatten each merge, losing how the branches were joined. Start from a commit after the merge, or use git rebase -i --rebase-merges in the console."
        case let .emptyRewordMessage(subject):
            "Write a new message for \"\(subject)\" or pick it instead of reword."
        case let .nothingToMeldInto(subject):
            "\"\(subject)\" cannot be squashed or fixed up: there is no earlier kept commit to meld it into. Pick the first commit."
        }
    }
}

extension FileChange {
    public var isUncommitted: Bool { !isUntracked && !isIgnored }
}

extension RepositorySnapshot {
    public var hasUncommittedChanges: Bool { changes.contains(where: \.isUncommitted) }
}
