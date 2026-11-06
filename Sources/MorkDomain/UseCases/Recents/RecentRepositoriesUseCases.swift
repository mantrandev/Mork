import Foundation

public protocol LoadRecentRepositoriesUseCaseProtocol: Sendable {
    func execute() -> [URL]
}

public protocol RememberRecentRepositoryUseCaseProtocol: Sendable {
    func execute(url: URL) -> [URL]
}

public protocol ClearRecentRepositoriesUseCaseProtocol: Sendable {
    func execute()
}

public final class LoadRecentRepositoriesUseCase: LoadRecentRepositoriesUseCaseProtocol {
    private let store: RecentRepositoriesRepositoryProtocol

    public init(store: RecentRepositoriesRepositoryProtocol) {
        self.store = store
    }

    public func execute() -> [URL] {
        let stored = store.load()
        let existing = RecentRepositoryList.normalized(stored.filter(store.exists))
        if existing != stored { store.save(existing) }
        return existing
    }
}

public final class RememberRecentRepositoryUseCase: RememberRecentRepositoryUseCaseProtocol {
    private let store: RecentRepositoriesRepositoryProtocol

    public init(store: RecentRepositoriesRepositoryProtocol) {
        self.store = store
    }

    public func execute(url: URL) -> [URL] {
        let updated = RecentRepositoryList.adding(url, to: store.load().filter(store.exists))
        store.save(updated)
        return updated
    }
}

public final class ClearRecentRepositoriesUseCase: ClearRecentRepositoriesUseCaseProtocol {
    private let store: RecentRepositoriesRepositoryProtocol

    public init(store: RecentRepositoriesRepositoryProtocol) {
        self.store = store
    }

    public func execute() {
        store.save([])
    }
}
