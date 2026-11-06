import Foundation

public enum CommitDetailsTab: String, CaseIterable, Identifiable, Sendable {
    case commit
    case changes
    case fileTree

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .commit: "Commit"
        case .changes: "Changes"
        case .fileTree: "File Tree"
        }
    }
}
