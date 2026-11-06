import Foundation

public enum PatchApplyMode: String, CaseIterable, Identifiable, Sendable {
    case workingTree
    case index
    case mailbox

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .workingTree: "Apply to working tree"
        case .index: "Apply to index (staging area)"
        case .mailbox: "Apply as commit (git am)"
        }
    }

    public var command: String {
        switch self {
        case .workingTree: "git apply"
        case .index: "git apply --cached"
        case .mailbox: "git am"
        }
    }

    public var explanation: String {
        switch self {
        case .workingTree: "Changes the files on disk. Nothing is staged or committed."
        case .index: "Changes only the staging area. The files on disk stay as they are."
        case .mailbox: "Creates a commit with the author, date and message stored in the patch. Needs a patch made by git format-patch."
        }
    }
}
