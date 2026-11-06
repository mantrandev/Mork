import Foundation

public protocol ValidateExternalToolUseCaseProtocol: Sendable {
    func execute(role: ExternalToolRole, settings: ExternalToolSettings) async -> ExternalToolCheck
}

public final class ValidateExternalToolUseCase: ValidateExternalToolUseCaseProtocol {
    private let resolve: ResolveExternalToolUseCaseProtocol

    public init(resolve: ResolveExternalToolUseCaseProtocol) {
        self.resolve = resolve
    }

    public func execute(role: ExternalToolRole, settings: ExternalToolSettings) async -> ExternalToolCheck {
        do {
            let launch = try await resolve.execute(role: role, settings: settings)
            let arguments = switch role {
            case .merge: ExternalToolCommand.merge(launch, trustsExitCode: settings.trustsExitCode, path: "")
            case .diff: ExternalToolCommand.diff(launch, revisions: [], path: "")
            }
            let name = ExternalToolCatalog.displayName(for: settings.tool(for: role)) ?? launch.tool
            return ExternalToolCheck(
                isReady: true,
                message: "\(name) is ready. The program exists and the command is complete; it was not started.",
                command: ExternalToolCommand.preview(arguments)
            )
        } catch {
            return ExternalToolCheck(isReady: false, message: error.localizedDescription, command: nil)
        }
    }
}
