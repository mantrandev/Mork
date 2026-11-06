import Foundation

public protocol SidebarOptionsRepositoryProtocol: Sendable {
    func load(for repository: URL) -> SidebarOptions?
    func save(_ options: SidebarOptions, for repository: URL)
}
