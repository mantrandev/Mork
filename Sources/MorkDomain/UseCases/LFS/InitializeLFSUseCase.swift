import Foundation

public protocol InitializeLFSUseCaseProtocol: Sendable {
    func execute() async throws
}

public final class InitializeLFSUseCase: InitializeLFSUseCaseProtocol {
    private let lfs: LFSRepositoryProtocol

    public init(lfs: LFSRepositoryProtocol) {
        self.lfs = lfs
    }

    public func execute() async throws {
        try await lfs.install()
    }
}
