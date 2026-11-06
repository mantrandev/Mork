import Foundation

public struct FileHistoryEntry: Identifiable, Hashable, Sendable {
    public let commit: Commit
    public let file: CommitFileChange

    public init(commit: Commit, file: CommitFileChange) {
        self.commit = commit
        self.file = file
    }

    public var id: String { commit.hash }
}
