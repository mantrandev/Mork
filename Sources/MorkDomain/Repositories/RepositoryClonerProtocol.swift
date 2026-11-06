import Foundation

public protocol RepositoryClonerProtocol: Sendable {
    func isAvailableDestination(_ url: URL) -> Bool
    func clone(from source: String, to destination: URL, progress: @escaping @Sendable (String) -> Void) async throws
}
