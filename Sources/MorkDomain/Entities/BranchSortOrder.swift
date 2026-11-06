import Foundation

public enum BranchSortOrder: String, Codable, CaseIterable, Sendable {
    case alphabetical
    case alphabeticalMainAndFoldersFirst
    case alphabeticalDescending
    case alphabeticalDescendingMainAndFoldersFirst
    case recentlyUsed

    public var title: String {
        switch self {
        case .alphabetical: "Alphabetically"
        case .alphabeticalMainAndFoldersFirst: "Alphabetically, master and folders on top"
        case .alphabeticalDescending: "Alphabetically backward"
        case .alphabeticalDescendingMainAndFoldersFirst: "Alphabetically backward, master and folders on top"
        case .recentlyUsed: "Recently used"
        }
    }
}
