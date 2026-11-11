import Foundation

public enum TagSortOrder: String, Codable, CaseIterable, Sendable {
    case alphabetical
    case alphabeticalFoldersFirst
    case alphabeticalDescending
    case alphabeticalDescendingFoldersFirst
    case recentlyUsed

    public var title: String {
        switch self {
        case .alphabetical: "Alphabetically"
        case .alphabeticalFoldersFirst: "Alphabetically, folders on top"
        case .alphabeticalDescending: "Alphabetically backward"
        case .alphabeticalDescendingFoldersFirst: "Alphabetically backward, folders on top"
        case .recentlyUsed: "Recently used"
        }
    }
}
