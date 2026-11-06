import Foundation

public protocol ApplyHunkUseCaseProtocol: Sendable {
    func execute(action: HunkAction, hunk: DiffHunk, patch: FilePatch, change: FileChange) async throws
}

public final class ApplyHunkUseCase: ApplyHunkUseCaseProtocol {
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(workingCopy: WorkingCopyRepositoryProtocol) {
        self.workingCopy = workingCopy
    }

    public func execute(action: HunkAction, hunk: DiffHunk, patch: FilePatch, change: FileChange) async throws {
        guard HunkAction.available(for: change, staged: action == .unstage).contains(action) else { return }
        guard !change.isUntracked else {
            if action == .stage { try await workingCopy.stage(paths: [change.path]) }
            if action == .discard { try await workingCopy.discard(change) }
            return
        }
        try await workingCopy.apply(patch: patch.patch(for: hunk), action: action)
    }
}
