import Foundation

public protocol TreemapRepositoryProtocol: Sendable {
    func files(at revision: String) async throws -> [TreemapFile]
}
