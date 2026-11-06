import Foundation

public protocol ApplyStashUseCaseProtocol: Sendable {
    func execute(stash: Stash, drop: Bool) async throws
}

public final class ApplyStashUseCase: ApplyStashUseCaseProtocol {
    private let stashes: StashRepositoryProtocol

    public init(stashes: StashRepositoryProtocol) {
        self.stashes = stashes
    }

    public func execute(stash: Stash, drop: Bool) async throws {
        try await stashes.apply(stash, drop: drop)
    }
}
