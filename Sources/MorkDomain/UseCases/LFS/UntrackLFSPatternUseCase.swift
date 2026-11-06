import Foundation

public protocol UntrackLFSPatternUseCaseProtocol: Sendable {
    func execute(pattern: String) async throws
}

public final class UntrackLFSPatternUseCase: UntrackLFSPatternUseCaseProtocol {
    private let lfs: LFSRepositoryProtocol

    public init(lfs: LFSRepositoryProtocol) {
        self.lfs = lfs
    }

    public func execute(pattern: String) async throws {
        let pattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pattern.isEmpty else { throw LFSError.emptyPattern }
        try await lfs.untrack(pattern: pattern)
    }
}
