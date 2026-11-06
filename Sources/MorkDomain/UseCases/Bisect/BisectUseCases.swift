import Foundation

public protocol StartBisectUseCaseProtocol: Sendable {
    func execute() async throws -> BisectState?
}

public protocol MarkBisectCommitUseCaseProtocol: Sendable {
    func execute(mark: BisectMark, commit: Commit?) async throws -> BisectState?
}

public protocol ResetBisectUseCaseProtocol: Sendable {
    func execute() async throws -> BisectResetResult
}

public protocol LoadBisectLogUseCaseProtocol: Sendable {
    func execute() async throws -> String
}

public final class StartBisectUseCase: StartBisectUseCaseProtocol {
    private let bisect: BisectRepositoryProtocol
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(bisect: BisectRepositoryProtocol, workingCopy: WorkingCopyRepositoryProtocol) {
        self.bisect = bisect
        self.workingCopy = workingCopy
    }

    public func execute() async throws -> BisectState? {
        if let session = try await bisect.session() { return session.state }
        try await workingCopy.requireCleanState()
        return try await bisect.start()
    }
}

public final class MarkBisectCommitUseCase: MarkBisectCommitUseCaseProtocol {
    private let bisect: BisectRepositoryProtocol
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(bisect: BisectRepositoryProtocol, workingCopy: WorkingCopyRepositoryProtocol) {
        self.bisect = bisect
        self.workingCopy = workingCopy
    }

    public func execute(mark: BisectMark, commit: Commit?) async throws -> BisectState? {
        if try await bisect.session() == nil {
            guard mark != .skip else { throw BisectError.notBisecting }
            try await workingCopy.requireCleanState()
            _ = try await bisect.start()
        }
        return try await bisect.mark(mark, revision: commit?.hash)
    }
}

public final class ResetBisectUseCase: ResetBisectUseCaseProtocol {
    private static let currentCommit = "HEAD"

    private let bisect: BisectRepositoryProtocol

    public init(bisect: BisectRepositoryProtocol) {
        self.bisect = bisect
    }

    public func execute() async throws -> BisectResetResult {
        guard let session = try await bisect.session() else { return .notBisecting }
        guard try await bisect.revisionExists(session.originalHead) else {
            try await bisect.reset(to: Self.currentCommit)
            return .originalHeadMissing(session.originalHead)
        }
        try await bisect.reset(to: nil)
        return .restored(session.originalHead)
    }
}

public final class LoadBisectLogUseCase: LoadBisectLogUseCaseProtocol {
    private let bisect: BisectRepositoryProtocol

    public init(bisect: BisectRepositoryProtocol) {
        self.bisect = bisect
    }

    public func execute() async throws -> String {
        guard try await bisect.session() != nil else { throw BisectError.notBisecting }
        return try await bisect.log()
    }
}
