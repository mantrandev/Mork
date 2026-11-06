import Foundation

public protocol TrackLFSPatternUseCaseProtocol: Sendable {
    func execute(pattern: String) async throws
}

public final class TrackLFSPatternUseCase: TrackLFSPatternUseCaseProtocol {
    private let lfs: LFSRepositoryProtocol

    public init(lfs: LFSRepositoryProtocol) {
        self.lfs = lfs
    }

    public func execute(pattern: String) async throws {
        let pattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pattern.isEmpty else { throw LFSError.emptyPattern }
        try await lfs.track(pattern: pattern)
    }

    public static func pattern(forFile path: String) -> String {
        let name = (path as NSString).lastPathComponent
        let fileExtension = (name as NSString).pathExtension
        guard !fileExtension.isEmpty, name != ".\(fileExtension)" else { return path }
        return "*.\(fileExtension)"
    }
}
