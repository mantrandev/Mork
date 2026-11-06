import Foundation

public protocol LoadHistoryOptionsUseCaseProtocol: Sendable {
    func execute(repository: URL) -> HistoryOptions
}

public protocol SaveHistoryOptionsUseCaseProtocol: Sendable {
    func execute(options: HistoryOptions, repository: URL)
}

public final class LoadHistoryOptionsUseCase: LoadHistoryOptionsUseCaseProtocol {
    private let store: HistoryOptionsRepositoryProtocol

    public init(store: HistoryOptionsRepositoryProtocol) {
        self.store = store
    }

    public func execute(repository: URL) -> HistoryOptions {
        store.load(for: repository) ?? .standard
    }
}

public final class SaveHistoryOptionsUseCase: SaveHistoryOptionsUseCaseProtocol {
    private let store: HistoryOptionsRepositoryProtocol

    public init(store: HistoryOptionsRepositoryProtocol) {
        self.store = store
    }

    public func execute(options: HistoryOptions, repository: URL) {
        store.save(options, for: repository)
    }
}
