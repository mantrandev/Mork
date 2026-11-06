import Foundation

public protocol OpenConflictInMergeToolUseCaseProtocol: Sendable {
    func execute(change: FileChange, settings: ExternalToolSettings) async throws -> MergeToolOutcome
}

public protocol OpenInDiffToolUseCaseProtocol: Sendable {
    func execute(path: String, target: ExternalDiffTarget, settings: ExternalToolSettings) async throws
}

public final class OpenConflictInMergeToolUseCase: OpenConflictInMergeToolUseCaseProtocol {
    private let resolve: ResolveExternalToolUseCaseProtocol
    private let tools: ExternalToolRepositoryProtocol
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(resolve: ResolveExternalToolUseCaseProtocol, tools: ExternalToolRepositoryProtocol, workingCopy: WorkingCopyRepositoryProtocol) {
        self.resolve = resolve
        self.tools = tools
        self.workingCopy = workingCopy
    }

    public func execute(change: FileChange, settings: ExternalToolSettings) async throws -> MergeToolOutcome {
        guard let kind = change.conflictKind else { throw ConflictError.notConflicted(path: change.path) }
        guard kind.hasContentConflict else { throw ExternalToolError.unsupportedConflict(kind) }
        let launch = try await resolve.execute(role: .merge, settings: settings)
        let exit = try await tools.runMergeTool(launch, trustsExitCode: settings.trustsExitCode, path: change.path)
        let stillConflicted = try await workingCopy.changes().contains { $0.path == change.path && $0.isConflicted }
        guard stillConflicted || exit.exitCode != 0 else { return .resolved }
        let output = exit.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return .unresolved(output.isEmpty ? "\(change.path) still has a conflict." : output)
    }
}

public final class OpenInDiffToolUseCase: OpenInDiffToolUseCaseProtocol {
    private let resolve: ResolveExternalToolUseCaseProtocol
    private let tools: ExternalToolRepositoryProtocol

    public init(resolve: ResolveExternalToolUseCaseProtocol, tools: ExternalToolRepositoryProtocol) {
        self.resolve = resolve
        self.tools = tools
    }

    public func execute(path: String, target: ExternalDiffTarget, settings: ExternalToolSettings) async throws {
        let launch = try await resolve.execute(role: .diff, settings: settings)
        let exit = try await tools.runDiffTool(launch, target: target, path: path)
        guard exit.exitCode == 0 else {
            throw ExternalToolError.diffFailed(exit.output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
