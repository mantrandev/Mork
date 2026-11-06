import Foundation

public protocol LoadImageDiffUseCaseProtocol: Sendable {
    func execute(sources: ImageDiffSources, limit: Int) async throws -> ImageDiff
}

public final class LoadImageDiffUseCase: LoadImageDiffUseCaseProtocol {
    private let blobs: BlobRepositoryProtocol

    public init(blobs: BlobRepositoryProtocol) {
        self.blobs = blobs
    }

    public func execute(sources: ImageDiffSources, limit: Int) async throws -> ImageDiff {
        async let old = load(sources.old, limit: limit)
        async let new = load(sources.new, limit: limit)
        return try await ImageDiff(old: old, new: new)
    }

    private func load(_ blob: BlobReference?, limit: Int) async throws -> ImageBlob {
        guard let blob else { return .missing }
        let size = try await blobs.size(of: blob)
        guard size <= limit else { return .tooLarge(byteCount: size) }
        return .loaded(try await blobs.data(of: blob))
    }
}
