import Foundation

public enum AuthorAvatarError: Error, Equatable, Sendable {
    case notFound
    case unavailable
}

public protocol AuthorAvatarRepositoryProtocol: Sendable {
    func avatar(forEmail email: String) async throws -> Data
}
