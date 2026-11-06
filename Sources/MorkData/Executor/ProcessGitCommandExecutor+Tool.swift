import MorkDomain
import Foundation

public protocol GitToolCommandExecuting: GitStreamingCommandExecuting {
    func runTool(_ arguments: [String], kind: GitCommandKind) async throws -> ExternalToolExit
}

extension ProcessGitCommandExecutor: GitToolCommandExecuting {
    private static let toolQueue = DispatchQueue(label: "mork.git.tools", qos: .userInitiated, attributes: .concurrent)

    public func runTool(_ arguments: [String], kind: GitCommandKind) async throws -> ExternalToolExit {
        let started = Date()
        let directory = directory
        let cancellation = ProcessTreeCancellation()
        let output = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                Self.toolQueue.async {
                    continuation.resume(with: Result {
                        try ProcessRunner.runTool(arguments, in: directory, cancellation: cancellation)
                    })
                }
            }
        } onCancel: {
            cancellation.cancel()
        }
        await logger?.record(GitCommandRecord(
            arguments: arguments,
            kind: kind,
            exitCode: output.exitCode,
            stdout: output.stdout,
            stderr: "",
            startedAt: started,
            duration: Date().timeIntervalSince(started)
        ).redacted())
        if cancellation.isCancelled { throw CancellationError() }
        return ExternalToolExit(exitCode: output.exitCode, output: output.stdout)
    }
}
