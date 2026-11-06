import Foundation

public protocol OpenInIntegrationAppUseCaseProtocol: Sendable {
    func openFolder(_ path: String, in kind: IntegrationAppKind, settings: IntegrationSettings) async throws
    func openFile(_ path: String, line: Int?, settings: IntegrationSettings) async throws
}

public final class OpenInIntegrationAppUseCase: OpenInIntegrationAppUseCaseProtocol {
    private let detect: DetectIntegrationsUseCaseProtocol
    private let detector: IntegrationDetectorProtocol
    private let launcher: ApplicationLauncherProtocol

    public init(detect: DetectIntegrationsUseCaseProtocol, detector: IntegrationDetectorProtocol, launcher: ApplicationLauncherProtocol) {
        self.detect = detect
        self.detector = detector
        self.launcher = launcher
    }

    public func openFolder(_ path: String, in kind: IntegrationAppKind, settings: IntegrationSettings) async throws {
        try await launcher.launch(launch(kind, settings: settings, path: path, line: nil) { IntegrationLaunchBuilder.folder($0, path: path) })
    }

    public func openFile(_ path: String, line: Int?, settings: IntegrationSettings) async throws {
        try await launcher.launch(launch(.editor, settings: settings, path: path, line: line) { IntegrationLaunchBuilder.file($0, path: path, line: line) })
    }

    private func launch(
        _ kind: IntegrationAppKind,
        settings: IntegrationSettings,
        path: String,
        line: Int?,
        build: (DetectedIntegrationApp) -> ApplicationLaunch
    ) async throws -> ApplicationLaunch {
        guard let selection = settings.selection(for: kind) else { throw IntegrationError.notConfigured(kind) }
        if selection == ExternalToolSettings.customID {
            let command = try validated(settings.customCommand(for: kind), kind: kind)
            return IntegrationLaunchBuilder.custom(command, kind: kind, path: path, line: line)
        }
        let name = IntegrationAppCatalog.displayName(for: selection, kind: kind) ?? selection
        guard let app = await detect.execute(rescan: false).apps(kind).first(where: { $0.id == selection }), detector.isExecutable(app.application) else {
            throw IntegrationError.appNotFound(name)
        }
        return build(app)
    }

    private func validated(_ text: String, kind: IntegrationAppKind) throws -> String {
        let command = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let program = ShellWords.split(command).first else { throw IntegrationError.emptyCommand(kind) }
        guard command.contains("$\(kind.placeholder)") || command.contains("${\(kind.placeholder)}") else {
            throw IntegrationError.missingPlaceholder(kind)
        }
        let found = program.contains("/") ? detector.isExecutable(program) : detector.locate(command: program) != nil
        guard found else { throw IntegrationError.commandNotFound(program) }
        return command
    }
}
