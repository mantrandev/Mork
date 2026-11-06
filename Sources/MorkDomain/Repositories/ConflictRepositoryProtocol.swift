import Foundation

public protocol ConflictRepositoryProtocol: Sendable {
    func contents(of path: String) async throws -> Data?
    func stage(_ stage: ConflictStage, of path: String) async throws -> Data
    func mergeFile(_ input: ConflictMergeInput, style: ConflictMarkerStyle) async throws -> Data
    func saveResolution(_ content: String, to path: String) async throws
    func checkout(_ side: ConflictSide, path: String) async throws
    func markResolved(path: String) async throws
    func remove(path: String) async throws
    func concludeMerge() async throws
}
