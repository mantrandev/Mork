import Foundation

public protocol IntegrationDetectorProtocol: Sendable {
    func detect() async -> IntegrationInventory
    func isExecutable(_ path: String) -> Bool
    func locate(command: String) -> String?
}

public protocol ExternalToolRepositoryProtocol: Sendable {
    func runMergeTool(_ launch: ExternalToolLaunch, trustsExitCode: Bool, path: String) async throws -> ExternalToolExit
    func runDiffTool(_ launch: ExternalToolLaunch, target: ExternalDiffTarget, path: String) async throws -> ExternalToolExit
}

public protocol ApplicationLauncherProtocol: Sendable {
    func launch(_ launch: ApplicationLaunch) async throws
}
