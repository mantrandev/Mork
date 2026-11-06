import MorkDomain

public struct SidebarOptionsDependencies: Sendable {
    public let load: LoadSidebarOptionsUseCaseProtocol
    public let save: SaveSidebarOptionsUseCaseProtocol

    public init(load: LoadSidebarOptionsUseCaseProtocol, save: SaveSidebarOptionsUseCaseProtocol) {
        self.load = load
        self.save = save
    }
}
