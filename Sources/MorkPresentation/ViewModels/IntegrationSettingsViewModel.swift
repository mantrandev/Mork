import MorkDomain
import Foundation
import Observation

public struct IntegrationChoice: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let application: String?
    public let isInstalled: Bool

    public init(id: String, name: String, application: String?, isInstalled: Bool) {
        self.id = id
        self.name = name
        self.application = application
        self.isInstalled = isInstalled
    }
}

@MainActor
@Observable
public final class IntegrationSettingsViewModel {
    private struct Check {
        let settings: ExternalToolSettings
        let result: ExternalToolCheck
    }

    public private(set) var inventory: Loadable<IntegrationInventory> = .idle
    public private(set) var isRescanning = false
    private var checks: [ExternalToolRole: Check] = [:]

    @ObservationIgnored private let dependencies: IntegrationSettingsDependencies

    public init(dependencies: IntegrationSettingsDependencies) {
        self.dependencies = dependencies
    }

    private var detected: IntegrationInventory {
        guard case let .loaded(inventory) = inventory else { return .empty }
        return inventory
    }

    public func load() async {
        if case .loaded = inventory { return }
        inventory = .loading
        inventory = .loaded(await dependencies.detectIntegrations.execute(rescan: false))
    }

    public func rescan() async {
        guard !isRescanning else { return }
        isRescanning = true
        defer { isRescanning = false }
        inventory = .loaded(await dependencies.detectIntegrations.execute(rescan: true))
        checks = [:]
    }

    public func test(_ role: ExternalToolRole, settings: ExternalToolSettings) async {
        checks[role] = Check(settings: settings, result: await dependencies.validateExternalTool.execute(role: role, settings: settings))
    }

    public func check(for role: ExternalToolRole, settings: ExternalToolSettings) -> ExternalToolCheck? {
        guard let check = checks[role], check.settings == settings else { return nil }
        return check.result
    }

    public func toolChoices(selection: String?) -> [IntegrationChoice] {
        let found = detected.tools.map { IntegrationChoice(id: $0.id, name: $0.name, application: Self.application(containing: $0.executable), isInstalled: true) }
        return found + missing(selection, among: found) { ExternalToolCatalog.displayName(for: $0) }
    }

    public func appChoices(_ kind: IntegrationAppKind, selection: String?) -> [IntegrationChoice] {
        let found = detected.apps(kind).map { IntegrationChoice(id: $0.id, name: $0.name, application: $0.application, isInstalled: true) }
        return found + missing(selection, among: found) { IntegrationAppCatalog.displayName(for: $0, kind: kind) }
    }

    private func missing(_ selection: String?, among found: [IntegrationChoice], name: (String) -> String?) -> [IntegrationChoice] {
        guard let selection, selection != ExternalToolSettings.customID, !found.contains(where: { $0.id == selection }) else { return [] }
        return [IntegrationChoice(id: selection, name: "\(name(selection) ?? selection) (not found)", application: nil, isInstalled: false)]
    }

    nonisolated static func application(containing executable: String) -> String? {
        guard let range = executable.range(of: ".app/") else { return nil }
        return String(executable[..<range.lowerBound]) + ".app"
    }
}
