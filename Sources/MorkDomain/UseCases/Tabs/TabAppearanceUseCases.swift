import Foundation

public protocol LoadTabAppearancesUseCaseProtocol: Sendable {
    func execute() -> TabAppearances
}

public protocol SaveTabAppearancesUseCaseProtocol: Sendable {
    func execute(appearances: TabAppearances)
}

public final class LoadTabAppearancesUseCase: LoadTabAppearancesUseCaseProtocol {
    private let store: TabAppearanceStoreProtocol

    public init(store: TabAppearanceStoreProtocol) {
        self.store = store
    }

    public func execute() -> TabAppearances {
        store.load()
    }
}

public final class SaveTabAppearancesUseCase: SaveTabAppearancesUseCaseProtocol {
    private let store: TabAppearanceStoreProtocol

    public init(store: TabAppearanceStoreProtocol) {
        self.store = store
    }

    public func execute(appearances: TabAppearances) {
        store.save(appearances)
    }
}
