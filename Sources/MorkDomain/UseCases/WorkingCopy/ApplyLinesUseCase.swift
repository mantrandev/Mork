import Foundation

public protocol ApplyLinesUseCaseProtocol: Sendable {
    func execute(action: HunkAction, selection: DiffLineSelection, patch: FilePatch, change: FileChange) async throws
}

public final class ApplyLinesUseCase: ApplyLinesUseCaseProtocol {
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(workingCopy: WorkingCopyRepositoryProtocol) {
        self.workingCopy = workingCopy
    }

    public func execute(action: HunkAction, selection: DiffLineSelection, patch: FilePatch, change: FileChange) async throws {
        guard HunkAction.available(for: change, staged: action == .unstage).contains(action) else { return }
        guard !(change.isUntracked && action == .unstage) else { return }
        guard let text = LinePatchBuilder.patch(for: patch, selection: selection, action: action) else { return }
        try await workingCopy.apply(patch: text, action: action)
    }
}
