import Foundation

public protocol LoadRepositoryTabsUseCaseProtocol: Sendable {
    func execute() -> RepositoryTabSession
}

public protocol SaveRepositoryTabsUseCaseProtocol: Sendable {
    func execute(session: RepositoryTabSession)
}

public protocol CheckRepositoryExistsUseCaseProtocol: Sendable {
    func execute(url: URL) -> Bool
}

public final class LoadRepositoryTabsUseCase: LoadRepositoryTabsUseCaseProtocol {
    private let store: RepositoryTabsRepositoryProtocol

    public init(store: RepositoryTabsRepositoryProtocol) {
        self.store = store
    }

    public func execute() -> RepositoryTabSession {
        let stored = store.load()
        var existing = stored
        existing.tabs = stored.tabs.filter(store.exists)
        let session = existing.normalized()
        if session != stored { store.save(session) }
        return session
    }
}

public final class SaveRepositoryTabsUseCase: SaveRepositoryTabsUseCaseProtocol {
    private let store: RepositoryTabsRepositoryProtocol

    public init(store: RepositoryTabsRepositoryProtocol) {
        self.store = store
    }

    public func execute(session: RepositoryTabSession) {
        store.save(session.normalized())
    }
}

public final class CheckRepositoryExistsUseCase: CheckRepositoryExistsUseCaseProtocol {
    private let store: RepositoryTabsRepositoryProtocol

    public init(store: RepositoryTabsRepositoryProtocol) {
        self.store = store
    }

    public func execute(url: URL) -> Bool {
        store.exists(url)
    }
}
