import Foundation

public struct ComparedFile: Identifiable, Hashable, Sendable {
    public static let untrackedStatus: Character = "A"

    public let id: String
    public let path: String
    public let status: Character
    public let originalPath: String?
    public let isUntracked: Bool

    public static func changed(_ change: CommitFileChange) -> ComparedFile {
        ComparedFile(id: "changed:\(change.path)", path: change.path, status: change.status, originalPath: change.originalPath, isUntracked: false)
    }

    public static func untracked(_ path: String) -> ComparedFile {
        ComparedFile(id: "untracked:\(path)", path: path, status: untrackedStatus, originalPath: nil, isUntracked: true)
    }

    public var change: CommitFileChange {
        CommitFileChange(status: status, path: path, originalPath: originalPath)
    }
}

public struct LocalChangesComparison: Equatable, Sendable {
    public let changed: [ComparedFile]
    public let untracked: [ComparedFile]
    public let files: [ComparedFile]

    public init(changed: [CommitFileChange], untracked: [String]) {
        self.changed = changed.map(ComparedFile.changed)
        self.untracked = untracked.map(ComparedFile.untracked)
        files = self.changed + self.untracked
    }

    public var isEmpty: Bool { files.isEmpty }
    public var count: Int { files.count }
}
