import Foundation

public struct RepositoryReadme: Equatable, Sendable {
    public let fileName: String
    public let text: String
    public let isTruncated: Bool

    public init(fileName: String, text: String, isTruncated: Bool) {
        self.fileName = fileName
        self.text = text
        self.isTruncated = isTruncated
    }
}

public struct RepositoryOverview: Equatable, Sendable {
    public let changedFiles: Int
    public let repositorySizeBytes: Int64
    public let commitCount: Int
    public let initialCommitDate: Date?
    public let lastCommitDate: Date?
    public let remotes: [Remote]
    public let readme: RepositoryReadme?

    public init(
        changedFiles: Int,
        repositorySizeBytes: Int64,
        commitCount: Int,
        initialCommitDate: Date?,
        lastCommitDate: Date?,
        remotes: [Remote],
        readme: RepositoryReadme?
    ) {
        self.changedFiles = changedFiles
        self.repositorySizeBytes = repositorySizeBytes
        self.commitCount = commitCount
        self.initialCommitDate = initialCommitDate
        self.lastCommitDate = lastCommitDate
        self.remotes = remotes
        self.readme = readme
    }
}
