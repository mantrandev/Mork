import Foundation

public protocol BisectRepositoryProtocol: Sendable {
    func session() async throws -> BisectSession?
    func start() async throws -> BisectState?
    func mark(_ mark: BisectMark, revision: String?) async throws -> BisectState?
    func reset(to revision: String?) async throws
    func log() async throws -> String
    func revisionExists(_ revision: String) async throws -> Bool
}
