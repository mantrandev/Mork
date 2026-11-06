import Foundation

public protocol CommitTreeRepositoryProtocol: Sendable {
    func entries(at revision: String, in directory: String) async throws -> [TreeEntry]
}

public protocol BlobRepositoryProtocol: Sendable {
    func size(of blob: BlobReference) async throws -> Int
    func data(of blob: BlobReference) async throws -> Data
    func export(_ blob: BlobReference, to destination: URL) async throws
}
