import Foundation

public protocol RebaseRepositoryProtocol: Sendable {
    func steps(from base: RebaseBase) async throws -> [RebaseStep]
    func startInteractiveRebase(onto base: RebaseBase, todo: RebaseTodo, autostash: Bool, updateRefs: Bool) async throws
    func rebase(onto branch: Branch, autostash: Bool) async throws
    func continueRebase() async throws
    func skipRebase() async throws
    func abortRebase() async throws
}
