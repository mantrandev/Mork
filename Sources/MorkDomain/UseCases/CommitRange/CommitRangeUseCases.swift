import Foundation

public protocol CherryPickCommitsUseCaseProtocol: Sendable {
    func execute(newestFirst commits: [Commit], options: CherryPickOptions) async throws
}

public final class CherryPickCommitsUseCase: CherryPickCommitsUseCaseProtocol {
    private let revisions: RevisionRepositoryProtocol
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(revisions: RevisionRepositoryProtocol, workingCopy: WorkingCopyRepositoryProtocol) {
        self.revisions = revisions
        self.workingCopy = workingCopy
    }

    public func execute(newestFirst commits: [Commit], options: CherryPickOptions) async throws {
        guard !commits.isEmpty else { return }
        try await workingCopy.requireCleanState()
        try await revisions.cherryPick(commits.reversed(), mainline: commits.mainline, options: options)
    }
}

public protocol RevertCommitsUseCaseProtocol: Sendable {
    func execute(newestFirst commits: [Commit], options: RevertOptions) async throws
}

public final class RevertCommitsUseCase: RevertCommitsUseCaseProtocol {
    private let revisions: RevisionRepositoryProtocol
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(revisions: RevisionRepositoryProtocol, workingCopy: WorkingCopyRepositoryProtocol) {
        self.revisions = revisions
        self.workingCopy = workingCopy
    }

    public func execute(newestFirst commits: [Commit], options: RevertOptions) async throws {
        guard !commits.isEmpty else { return }
        try await workingCopy.requireCleanState()
        try await revisions.revert(commits, mainline: commits.mainline, options: options)
    }
}

public protocol CheckCommitRangeUseCaseProtocol: Sendable {
    func execute(oldest: Commit, newest: Commit) async throws -> CommitRange?
}

public final class CheckCommitRangeUseCase: CheckCommitRangeUseCaseProtocol {
    private let ranges: CommitRangeRepositoryProtocol

    public init(ranges: CommitRangeRepositoryProtocol) {
        self.ranges = ranges
    }

    public func execute(oldest: Commit, newest: Commit) async throws -> CommitRange? {
        guard oldest.hash != newest.hash, try await ranges.isAncestor(oldest, of: newest) else { return nil }
        return CommitRange(oldest: oldest, newest: newest)
    }
}

public protocol LoadCommitRangeChangesUseCaseProtocol: Sendable {
    func execute(range: CommitRange) async throws -> [ComparedFile]
}

public final class LoadCommitRangeChangesUseCase: LoadCommitRangeChangesUseCaseProtocol {
    private let ranges: CommitRangeRepositoryProtocol

    public init(ranges: CommitRangeRepositoryProtocol) {
        self.ranges = ranges
    }

    public func execute(range: CommitRange) async throws -> [ComparedFile] {
        try await ranges.changedFiles(in: range).map(ComparedFile.changed)
    }
}

public protocol LoadCommitRangeDiffUseCaseProtocol: Sendable {
    func execute(range: CommitRange, file: ComparedFile) async throws -> String
}

public final class LoadCommitRangeDiffUseCase: LoadCommitRangeDiffUseCaseProtocol {
    private let ranges: CommitRangeRepositoryProtocol

    public init(ranges: CommitRangeRepositoryProtocol) {
        self.ranges = ranges
    }

    public func execute(range: CommitRange, file: ComparedFile) async throws -> String {
        try await ranges.diff(in: range, file: file.change)
    }
}

public protocol SaveCommitRangePatchUseCaseProtocol: Sendable {
    func execute(range: CommitRange, folder: URL) async throws -> [String]
}

public final class SaveCommitRangePatchUseCase: SaveCommitRangePatchUseCaseProtocol {
    private let ranges: CommitRangeRepositoryProtocol

    public init(ranges: CommitRangeRepositoryProtocol) {
        self.ranges = ranges
    }

    public func execute(range: CommitRange, folder: URL) async throws -> [String] {
        try await ranges.formatPatches(of: range, into: folder)
    }
}
