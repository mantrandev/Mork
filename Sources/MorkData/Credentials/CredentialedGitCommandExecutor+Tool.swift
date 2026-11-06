import MorkDomain
import Foundation

extension CredentialedGitCommandExecutor: GitToolCommandExecuting {
    public func runTool(_ arguments: [String], kind: GitCommandKind) async throws -> ExternalToolExit {
        guard let tools = base as? GitToolCommandExecuting else {
            throw GitDomainError.commandFailed(command: (["git"] + arguments).joined(separator: " "), exitCode: -1, message: "This git runner cannot start external tools.")
        }
        return try await tools.runTool(arguments, kind: kind)
    }
}
