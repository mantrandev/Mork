import Foundation

public enum GitDomainError: LocalizedError, Sendable, Equatable {
    case notARepository(path: String)
    case commandFailed(command: String, exitCode: Int32, message: String)
    case emptyCommitMessage
    case nothingStaged
    case nothingToStash
    case emptyBranchName
    case emptyTagName
    case noRemote
    case ambiguousRemote([String])
    case detachedHead
    case cannotDeleteCurrentBranch
    case cannotDeleteRemoteBranch
    case operationInProgress(RepositoryState)
    case invalidIgnorePattern
    case notAMailboxPatch
    case emptyPatch

    public var errorDescription: String? {
        switch self {
        case let .notARepository(path):
            "\(path) is not a Git repository."
        case let .commandFailed(command, exitCode, message):
            "\(command)\nexit \(exitCode)\n\(message)" + (SigningFailure.hint(for: message).map { "\n\n" + $0 } ?? "")
        case .emptyCommitMessage:
            "Commit message cannot be empty."
        case .nothingStaged:
            "No files are staged. Stage files before committing."
        case .nothingToStash:
            "There are no changes to stash."
        case .emptyBranchName:
            "Branch name cannot be empty."
        case .emptyTagName:
            "Tag name cannot be empty."
        case .noRemote:
            "This repository has no remote. Add one with: git remote add origin <url>"
        case let .ambiguousRemote(remotes):
            "Several remotes (\(remotes.joined(separator: ", "))) and no origin. Push from the console: git push -u <remote> <branch>"
        case .detachedHead:
            "HEAD is detached: there is no current branch. Create a branch here or switch to a branch first."
        case .cannotDeleteCurrentBranch:
            "Cannot delete the checked-out branch. Switch to another branch first."
        case .cannotDeleteRemoteBranch:
            "Delete remote branches from the console: git push <remote> --delete <branch>"
        case let .operationInProgress(state):
            "A \(state.operationName) is in progress. Finish it or abort it first."
        case .invalidIgnorePattern:
            "An ignore rule must be one non-empty line."
        case .notAMailboxPatch:
            "git am needs a mailbox patch made by git format-patch (it starts with \"From <commit>\"). Apply this file with git apply instead."
        case .emptyPatch:
            "The file contains no diff that git could apply."
        }
    }
}

private extension RepositoryState {
    var operationName: String {
        switch self {
        case .merging: "merge"
        case .rebasing: "rebase"
        case .cherryPicking: "cherry-pick"
        case .reverting: "revert"
        case .clean: "operation"
        }
    }
}
