import Foundation

public protocol PullPreferencesRepositoryProtocol: Sendable {
    func pullMode(for repository: URL) -> PullMode?
    func savePullMode(_ mode: PullMode, for repository: URL)
    func autostash(for repository: URL) -> Bool?
    func saveAutostash(_ autostash: Bool, for repository: URL)
}

extension PullPreferencesRepositoryProtocol {
    public func autostash(for repository: URL) -> Bool? { nil }
    public func saveAutostash(_ autostash: Bool, for repository: URL) {}
}
