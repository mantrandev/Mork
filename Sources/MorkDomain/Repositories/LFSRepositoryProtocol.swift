import Foundation

public protocol LFSRepositoryProtocol: Sendable {
    func version() async throws -> String?
    func install() async throws
    func trackedPatterns() async throws -> [String]
    func track(pattern: String) async throws
    func untrack(pattern: String) async throws
    func fetch(progress: @escaping @Sendable (String) -> Void) async throws
    func pull(progress: @escaping @Sendable (String) -> Void) async throws
    func lfsPaths(_ paths: [String], revision: String?) async throws -> Set<String>
}
