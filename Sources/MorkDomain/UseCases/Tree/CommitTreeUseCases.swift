import Foundation

public protocol LoadTreeEntriesUseCaseProtocol: Sendable {
    func execute(revision: String, directory: String) async throws -> [TreeEntry]
}

public final class LoadTreeEntriesUseCase: LoadTreeEntriesUseCaseProtocol {
    private let tree: CommitTreeRepositoryProtocol

    public init(tree: CommitTreeRepositoryProtocol) {
        self.tree = tree
    }

    public func execute(revision: String, directory: String) async throws -> [TreeEntry] {
        TreeEntry.sorted(try await tree.entries(at: revision, in: directory))
    }
}

public protocol LoadFileAtRevisionUseCaseProtocol: Sendable {
    func execute(blob: BlobReference, size: Int?, limit: Int) async throws -> FileRevisionContent
}

extension LoadFileAtRevisionUseCaseProtocol {
    public func execute(blob: BlobReference, limit: Int) async throws -> FileRevisionContent {
        try await execute(blob: blob, size: nil, limit: limit)
    }
}

public final class LoadFileAtRevisionUseCase: LoadFileAtRevisionUseCaseProtocol {
    private let blobs: BlobRepositoryProtocol

    public init(blobs: BlobRepositoryProtocol) {
        self.blobs = blobs
    }

    public func execute(blob: BlobReference, size known: Int?, limit: Int) async throws -> FileRevisionContent {
        let size = if let known { known } else { try await blobs.size(of: blob) }
        guard size <= limit else { return .tooLarge(byteCount: size) }
        return FileRevisionContent.make(try await blobs.data(of: blob))
    }
}

public protocol SaveFileAtRevisionUseCaseProtocol: Sendable {
    func execute(blob: BlobReference, destination: URL) async throws
}

public final class SaveFileAtRevisionUseCase: SaveFileAtRevisionUseCaseProtocol {
    private let blobs: BlobRepositoryProtocol

    public init(blobs: BlobRepositoryProtocol) {
        self.blobs = blobs
    }

    public func execute(blob: BlobReference, destination: URL) async throws {
        try await blobs.export(blob, to: destination)
    }
}
