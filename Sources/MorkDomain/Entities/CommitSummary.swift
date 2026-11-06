import Foundation

public struct CommitFileChange: Identifiable, Hashable, Sendable {
    public let status: Character
    public let path: String
    public let originalPath: String?

    public init(status: Character, path: String, originalPath: String? = nil) {
        self.status = status
        self.path = path
        self.originalPath = originalPath
    }

    public var id: String { path }
}

public struct CommitSummary: Equatable, Sendable {
    public let commit: Commit
    public let message: String
    public let files: [CommitFileChange]
    public let signature: CommitSignatureDetails?

    public init(commit: Commit, message: String, files: [CommitFileChange], signature: CommitSignatureDetails? = nil) {
        self.commit = commit
        self.message = message
        self.files = files
        self.signature = signature
    }

    public var isRoot: Bool { commit.parents.isEmpty }
    public var comparedFirstParent: String? { commit.isMerge ? commit.parents.first : nil }
}
