import Foundation

public enum LFSTransfer: String, Sendable, Equatable, CaseIterable {
    case fetch
    case pull

    public var commandLine: String { "git lfs \(rawValue)" }
}

public protocol TransferLFSObjectsUseCaseProtocol: Sendable {
    func execute(_ transfer: LFSTransfer, progress: @escaping @Sendable (String) -> Void) async throws
}

public final class TransferLFSObjectsUseCase: TransferLFSObjectsUseCaseProtocol {
    private let lfs: LFSRepositoryProtocol

    public init(lfs: LFSRepositoryProtocol) {
        self.lfs = lfs
    }

    public func execute(_ transfer: LFSTransfer, progress: @escaping @Sendable (String) -> Void) async throws {
        switch transfer {
        case .fetch: try await lfs.fetch(progress: progress)
        case .pull: try await lfs.pull(progress: progress)
        }
    }
}
