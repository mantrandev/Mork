import Foundation

public protocol LoadLFSFilesUseCaseProtocol: Sendable {
    func execute(paths: [String], revision: String?) async throws -> Set<String>
}

public final class LoadLFSFilesUseCase: LoadLFSFilesUseCaseProtocol {
    private let lfs: LFSRepositoryProtocol

    public init(lfs: LFSRepositoryProtocol) {
        self.lfs = lfs
    }

    public func execute(paths: [String], revision: String?) async throws -> Set<String> {
        let unique = Array(Set(paths)).sorted()
        guard !unique.isEmpty else { return [] }
        return try await lfs.lfsPaths(unique, revision: revision)
    }
}
