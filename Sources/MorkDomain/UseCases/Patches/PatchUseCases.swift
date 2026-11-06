import Foundation

public protocol LoadPatchPreviewUseCaseProtocol: Sendable {
    func execute(file: URL) async throws -> PatchPreview
}

public final class LoadPatchPreviewUseCase: LoadPatchPreviewUseCaseProtocol {
    private let patches: PatchRepositoryProtocol

    public init(patches: PatchRepositoryProtocol) {
        self.patches = patches
    }

    public func execute(file: URL) async throws -> PatchPreview {
        PatchPreview.parse(try await patches.readPatch(at: file))
    }
}

public protocol CheckPatchUseCaseProtocol: Sendable {
    func execute(file: URL, mode: PatchApplyMode) async throws
}

public final class CheckPatchUseCase: CheckPatchUseCaseProtocol {
    private let patches: PatchRepositoryProtocol

    public init(patches: PatchRepositoryProtocol) {
        self.patches = patches
    }

    public func execute(file: URL, mode: PatchApplyMode) async throws {
        try await patches.check(patchAt: file, mode: mode)
    }
}

public protocol ApplyPatchUseCaseProtocol: Sendable {
    func execute(file: URL, mode: PatchApplyMode) async throws
}

public final class ApplyPatchUseCase: ApplyPatchUseCaseProtocol {
    private let patches: PatchRepositoryProtocol

    public init(patches: PatchRepositoryProtocol) {
        self.patches = patches
    }

    public func execute(file: URL, mode: PatchApplyMode) async throws {
        let preview = PatchPreview.parse(try await patches.readPatch(at: file))
        guard !preview.files.isEmpty else { throw GitDomainError.emptyPatch }
        guard mode != .mailbox || preview.isMailbox else { throw GitDomainError.notAMailboxPatch }
        try await patches.check(patchAt: file, mode: mode)
        try await patches.apply(patchAt: file, mode: mode)
    }
}

public protocol CreatePatchUseCaseProtocol: Sendable {
    func execute(commit: Commit, destination: URL) async throws
}

public final class CreatePatchUseCase: CreatePatchUseCaseProtocol {
    private let patches: PatchRepositoryProtocol

    public init(patches: PatchRepositoryProtocol) {
        self.patches = patches
    }

    public func execute(commit: Commit, destination: URL) async throws {
        try await patches.export(commit, to: destination)
    }
}
