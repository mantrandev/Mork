import Foundation

public protocol LoadLFSPatternsUseCaseProtocol: Sendable {
    func execute() async throws -> [String]
}

public final class LoadLFSPatternsUseCase: LoadLFSPatternsUseCaseProtocol {
    private let lfs: LFSRepositoryProtocol

    public init(lfs: LFSRepositoryProtocol) {
        self.lfs = lfs
    }

    public func execute() async throws -> [String] {
        try await lfs.trackedPatterns()
    }
}
