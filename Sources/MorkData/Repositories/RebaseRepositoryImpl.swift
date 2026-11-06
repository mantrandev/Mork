import MorkDomain
import Foundation

public final class RebaseRepositoryImpl: RebaseRepositoryProtocol {
    private let executor: GitCommandExecuting
    private let scripts: RebaseEditorScripts

    public init(executor: GitCommandExecuting, scratchDirectory: URL = FileManager.default.temporaryDirectory) {
        self.executor = executor
        scripts = RebaseEditorScripts(directory: scratchDirectory)
    }

    public func steps(from base: RebaseBase) async throws -> [RebaseStep] {
        GitOutputParser.rebaseSteps(try await executor.read([
            "log", "--reverse", "--topo-order", "--format=\(GitOutputParser.rebaseStepFormat)", "\(base.revision)..HEAD"
        ]))
    }

    public func startInteractiveRebase(onto base: RebaseBase, todo: RebaseTodo, autostash: Bool, updateRefs: Bool) async throws {
        let plan = try scripts.writePlan(todo)
        defer { scripts.remove(plan) }
        try await executor.write(RebaseCommand.interactive(onto: base, autostash: autostash, updateRefs: updateRefs), environment: try scripts.environment(plan: plan))
    }

    public func rebase(onto branch: Branch, autostash: Bool) async throws {
        try await executor.write(RebaseCommand.onto(branch, autostash: autostash), environment: try scripts.editorEnvironment())
    }

    public func continueRebase() async throws {
        try await executor.write(["rebase", "--continue"], environment: try scripts.editorEnvironment())
    }

    public func skipRebase() async throws {
        try await executor.write(["rebase", "--skip"], environment: try scripts.editorEnvironment())
    }

    public func abortRebase() async throws {
        try await executor.write(["rebase", "--abort"])
    }
}
