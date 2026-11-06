import Foundation

public struct Commit: Identifiable, Hashable, Sendable {
    public let hash: String
    public let parents: [String]
    public let author: String
    public let authorEmail: String
    public let date: Date
    public let refs: String
    public let subject: String
    public let isLost: Bool
    public var syncStatus: CommitSyncStatus

    public init(hash: String, parents: [String], author: String, authorEmail: String = "", date: Date, refs: String, subject: String, isLost: Bool = false, syncStatus: CommitSyncStatus = .shared) {
        self.hash = hash
        self.parents = parents
        self.author = author
        self.authorEmail = authorEmail
        self.date = date
        self.refs = refs
        self.subject = subject
        self.isLost = isLost
        self.syncStatus = syncStatus
    }

    public var id: String { hash }
    public var shortHash: String { String(hash.prefix(7)) }
    public var isMerge: Bool { parents.count > 1 }
    public var refNames: [String] { refs.isEmpty ? [] : refs.components(separatedBy: ", ") }
}

public enum CommitSyncStatus: Hashable, Sendable {
    case shared
    case localOnly
    case remoteOnly
}
