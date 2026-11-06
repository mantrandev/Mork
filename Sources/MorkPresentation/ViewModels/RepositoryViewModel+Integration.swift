import MorkDomain
import Foundation

extension RepositoryViewModel {
    public var mergeToolName: String? { ExternalToolCatalog.displayName(for: settings.externalTools.mergeTool) }
    public var diffToolName: String? { ExternalToolCatalog.displayName(for: settings.externalTools.diffTool) }
    public var editorName: String? { IntegrationAppCatalog.displayName(for: settings.integration.editor, kind: .editor) }
    public var terminalAppName: String { IntegrationAppCatalog.displayName(for: settings.integration.terminal, kind: .terminal) ?? "Terminal" }

    public func openInMergeTool(_ change: FileChange) {
        let path = change.path
        let settings = settings.externalTools
        let openConflict = dependencies.integration.openConflictInMergeTool
        externalTools.start(path, ExternalToolRuns.Run(tool: mergeToolName ?? "the merge tool", role: .merge)) { [weak self] in
            var message: String?
            do {
                if case let .unresolved(output) = try await openConflict.execute(change: change, settings: settings) {
                    message = output
                }
            } catch is CancellationError {
            } catch {
                message = error.localizedDescription
            }
            await self?.refreshAfterMergeTool(path)
            return message
        }
    }

    public func cancelExternalTool(at path: String) {
        externalTools.cancel(path)
    }

    public func openInDiffTool(path: String, target: ExternalDiffTarget) {
        let settings = settings.externalTools
        let openDiff = dependencies.integration.openInDiffTool
        externalTools.start(path, ExternalToolRuns.Run(tool: diffToolName ?? "the diff tool", role: .diff)) { [weak self] in
            do {
                try await openDiff.execute(path: path, target: target, settings: settings)
            } catch is CancellationError {
            } catch {
                self?.errorMessage = error.localizedDescription
            }
            return nil
        }
    }

    public func openInEditor(path: String, line: Int? = nil) async {
        let file = url.appendingPathComponent(path).path
        let settings = settings.integration
        await openApp { try await $0.openFile(file, line: line, settings: settings) }
    }

    public func editorLocation(file: DiffFileSummary?, oldLine: Int?, newLine: Int?) -> (path: String, line: Int)? {
        guard let line = newLine ?? oldLine else { return nil }
        switch selection {
        case let .file(change, _):
            return (change.path, line)
        case let .commitFile(_, change):
            return change.status == "D" ? nil : (change.path, line)
        case .commit:
            guard let file, file.status != .deleted else { return nil }
            return (file.path, line)
        case nil:
            return nil
        }
    }

    public func openRepositoryInEditor() async {
        let folder = url.path
        let settings = settings.integration
        await openApp { try await $0.openFolder(folder, in: .editor, settings: settings) }
    }

    public func openRepositoryInTerminalApp() async {
        let folder = url.path
        let settings = settings.integration
        await openApp { try await $0.openFolder(folder, in: .terminal, settings: settings) }
    }

    private func openApp(_ body: (OpenInIntegrationAppUseCaseProtocol) async throws -> Void) async {
        do {
            try await body(dependencies.integration.openInApp)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshAfterMergeTool(_ path: String) async {
        let wasSelected = conflictResolver?.path == path
        await refresh()
        if wasSelected, selection == nil, let next = conflictedChanges.first {
            selection = .file(next, staged: false)
        }
    }
}
