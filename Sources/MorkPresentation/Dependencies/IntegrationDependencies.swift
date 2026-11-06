import MorkDomain
import Foundation

public struct IntegrationDependencies: Sendable {
    public let openConflictInMergeTool: OpenConflictInMergeToolUseCaseProtocol
    public let openInDiffTool: OpenInDiffToolUseCaseProtocol
    public let openInApp: OpenInIntegrationAppUseCaseProtocol

    public init(
        openConflictInMergeTool: OpenConflictInMergeToolUseCaseProtocol,
        openInDiffTool: OpenInDiffToolUseCaseProtocol,
        openInApp: OpenInIntegrationAppUseCaseProtocol
    ) {
        self.openConflictInMergeTool = openConflictInMergeTool
        self.openInDiffTool = openInDiffTool
        self.openInApp = openInApp
    }
}

public struct IntegrationSettingsDependencies: Sendable {
    public let detectIntegrations: DetectIntegrationsUseCaseProtocol
    public let validateExternalTool: ValidateExternalToolUseCaseProtocol

    public init(detectIntegrations: DetectIntegrationsUseCaseProtocol, validateExternalTool: ValidateExternalToolUseCaseProtocol) {
        self.detectIntegrations = detectIntegrations
        self.validateExternalTool = validateExternalTool
    }
}
