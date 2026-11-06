import Foundation

public struct TreeEntry: Identifiable, Hashable, Sendable {
    public enum Kind: String, Hashable, Sendable {
        case file
        case executable
        case symlink
        case directory
        case submodule
    }

    public let path: String
    public let kind: Kind
    public let object: String
    public let size: Int?

    public init(path: String, kind: Kind, object: String, size: Int?) {
        self.path = path
        self.kind = kind
        self.object = object
        self.size = size
    }

    public var id: String { path }
    public var name: String { path.split(separator: "/").last.map(String.init) ?? path }
    public var isDirectory: Bool { kind == .directory }
    public var hasContent: Bool { kind == .file || kind == .executable || kind == .symlink }

    public static func sorted(_ entries: [TreeEntry]) -> [TreeEntry] {
        entries.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            let order = lhs.name.localizedStandardCompare(rhs.name)
            return order == .orderedSame ? lhs.name < rhs.name : order == .orderedAscending
        }
    }
}
