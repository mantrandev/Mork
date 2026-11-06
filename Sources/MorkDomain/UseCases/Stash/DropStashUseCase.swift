import Foundation

public protocol DropStashUseCaseProtocol: Sendable {
    func execute(stash: Stash) async throws
}

public final class DropStashUseCase: DropStashUseCaseProtocol {
    private let stashes: StashRepositoryProtocol

    public init(stashes: StashRepositoryProtocol) {
        self.stashes = stashes
    }

    public func execute(stash: Stash) async throws {
        try await stashes.drop(stash)
    }
}
