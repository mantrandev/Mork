import Foundation

public protocol IgnoreRepositoryProtocol: Sendable {
    func contents(of target: IgnoreTarget) async throws -> String?
    func write(_ contents: String, to target: IgnoreTarget) async throws
    func matchingRule(for path: String) async throws -> IgnoreMatch?
}

public protocol PatchRepositoryProtocol: Sendable {
    func readPatch(at file: URL) async throws -> String
    func check(patchAt file: URL, mode: PatchApplyMode) async throws
    func apply(patchAt file: URL, mode: PatchApplyMode) async throws
    func export(_ commit: Commit, to destination: URL) async throws
}
