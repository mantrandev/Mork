import Foundation

public protocol ResolveExternalToolUseCaseProtocol: Sendable {
    func execute(role: ExternalToolRole, settings: ExternalToolSettings) async throws -> ExternalToolLaunch
}

public final class ResolveExternalToolUseCase: ResolveExternalToolUseCaseProtocol {
    private let detect: DetectIntegrationsUseCaseProtocol
    private let detector: IntegrationDetectorProtocol

    public init(detect: DetectIntegrationsUseCaseProtocol, detector: IntegrationDetectorProtocol) {
        self.detect = detect
        self.detector = detector
    }

    public func execute(role: ExternalToolRole, settings: ExternalToolSettings) async throws -> ExternalToolLaunch {
        guard let selection = settings.tool(for: role) else { throw ExternalToolError.notConfigured(role) }
        if selection == ExternalToolSettings.customID {
            return try custom(settings.customCommand(for: role), role: role)
        }
        let name = ExternalToolCatalog.displayName(for: selection) ?? selection
        guard let tool = await detect.execute(rescan: false).tools.first(where: { $0.id == selection }), detector.isExecutable(tool.executable) else {
            throw ExternalToolError.toolNotFound(name)
        }
        guard let arguments = tool.definition.arguments(for: role) else {
            return .backend(tool: tool.id, path: tool.executable)
        }
        return .command(tool: tool.id, command: "\(ShellWords.quote(tool.executable)) \(arguments)")
    }

    private func custom(_ text: String, role: ExternalToolRole) throws -> ExternalToolLaunch {
        let command = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let program = ShellWords.split(command).first else { throw ExternalToolError.emptyCommand(role) }
        let missing = role.requiredPlaceholders.filter { !command.contains("$\($0)") && !command.contains("${\($0)}") }
        guard missing.isEmpty else { throw ExternalToolError.missingPlaceholders(role, missing) }
        let found = program.contains("/") ? detector.isExecutable(program) : detector.locate(command: program) != nil
        guard found else { throw ExternalToolError.commandNotFound(program) }
        return .command(tool: ExternalToolSettings.customID, command: command)
    }
}
