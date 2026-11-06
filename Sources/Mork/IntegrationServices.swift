import AppKit
import MorkData
import MorkDomain
import MorkPresentation
import Foundation

struct IntegrationServices: Sendable {
    let detector: IntegrationDetectorProtocol
    let detect: DetectIntegrationsUseCaseProtocol
    let launcher: ApplicationLauncherProtocol

    init(detector: IntegrationDetectorProtocol, launcher: ApplicationLauncherProtocol) {
        self.detector = detector
        self.launcher = launcher
        detect = DetectIntegrationsUseCase(detector: detector)
    }

    static func standard() -> IntegrationServices {
        IntegrationServices(
            detector: FileSystemIntegrationDetector { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) },
            launcher: ApplicationLauncherImpl { urls, application in
                _ = try await NSWorkspace.shared.open(urls, withApplicationAt: application, configuration: NSWorkspace.OpenConfiguration())
            }
        )
    }

    var resolveTool: ResolveExternalToolUseCase {
        ResolveExternalToolUseCase(detect: detect, detector: detector)
    }

    var openInApp: OpenInIntegrationAppUseCase {
        OpenInIntegrationAppUseCase(detect: detect, detector: detector, launcher: launcher)
    }

    var settingsDependencies: IntegrationSettingsDependencies {
        IntegrationSettingsDependencies(detectIntegrations: detect, validateExternalTool: ValidateExternalToolUseCase(resolve: resolveTool))
    }

    func detectInBackground() {
        let detect = detect
        Task.detached(priority: .utility) { _ = await detect.execute(rescan: false) }
    }
}
