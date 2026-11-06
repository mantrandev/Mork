import Foundation

public struct CommitDetailsLayout: Equatable, Sendable {
    public enum FilesPlacement: String, CaseIterable, Sendable {
        case beside
        case above

        public var title: String {
            switch self {
            case .beside: "Changed Files Beside the Diff"
            case .above: "Changed Files Above the Diff"
            }
        }

        public var toggled: FilesPlacement {
            self == .beside ? .above : .beside
        }
    }

    public var showsHeader = true
    public var filesPlacement = FilesPlacement.beside

    public init(showsHeader: Bool = true, filesPlacement: FilesPlacement = .beside) {
        self.showsHeader = showsHeader
        self.filesPlacement = filesPlacement
    }
}
