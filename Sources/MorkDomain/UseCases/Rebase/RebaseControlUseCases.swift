import Foundation

public protocol ContinueRebaseUseCaseProtocol: Sendable {
    func execute() async throws
}

public protocol SkipRebaseUseCaseProtocol: Sendable {
    func execute() async throws
}

public protocol AbortRebaseUseCaseProtocol: Sendable {
    func execute() async throws
}

public final class ContinueRebaseUseCase: ContinueRebaseUseCaseProtocol {
    private let rebase: RebaseRepositoryProtocol
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(rebase: RebaseRepositoryProtocol, workingCopy: WorkingCopyRepositoryProtocol) {
        self.rebase = rebase
        self.workingCopy = workingCopy
    }

    public func execute() async throws {
        guard try await workingCopy.state() == .rebasing else { return }
        try await rebase.continueRebase()
    }
}

public final class SkipRebaseUseCase: SkipRebaseUseCaseProtocol {
    private let rebase: RebaseRepositoryProtocol
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(rebase: RebaseRepositoryProtocol, workingCopy: WorkingCopyRepositoryProtocol) {
        self.rebase = rebase
        self.workingCopy = workingCopy
    }

    public func execute() async throws {
        guard try await workingCopy.state() == .rebasing else { return }
        try await rebase.skipRebase()
    }
}

public final class AbortRebaseUseCase: AbortRebaseUseCaseProtocol {
    private let rebase: RebaseRepositoryProtocol
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(rebase: RebaseRepositoryProtocol, workingCopy: WorkingCopyRepositoryProtocol) {
        self.rebase = rebase
        self.workingCopy = workingCopy
    }

    public func execute() async throws {
        guard try await workingCopy.state() == .rebasing else { return }
        try await rebase.abortRebase()
    }
}
