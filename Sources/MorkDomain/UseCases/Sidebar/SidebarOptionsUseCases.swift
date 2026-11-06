import Foundation

public protocol LoadSidebarOptionsUseCaseProtocol: Sendable {
    func execute(repository: URL) -> SidebarOptions
}

public protocol SaveSidebarOptionsUseCaseProtocol: Sendable {
    func execute(options: SidebarOptions, repository: URL)
}

public final class LoadSidebarOptionsUseCase: LoadSidebarOptionsUseCaseProtocol {
    private let store: SidebarOptionsRepositoryProtocol
    public init(store: SidebarOptionsRepositoryProtocol) { self.store = store }
    public func execute(repository: URL) -> SidebarOptions { store.load(for: repository) ?? .standard }
}

public final class SaveSidebarOptionsUseCase: SaveSidebarOptionsUseCaseProtocol {
    private let store: SidebarOptionsRepositoryProtocol
    public init(store: SidebarOptionsRepositoryProtocol) { self.store = store }
    public func execute(options: SidebarOptions, repository: URL) { store.save(options, for: repository) }
}
