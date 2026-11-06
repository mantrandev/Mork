import MorkDomain
import Foundation
import Observation

@MainActor
@Observable
public final class SettingsViewModel {
    public enum Tab: String, CaseIterable, Identifiable, Sendable {
        case general = "General"
        case git = "Git"
        case diff = "Diff"
        case learning = "Learning"
        case accounts = "Accounts"
        case ssh = "SSH"
        case integration = "Integration"
        case customCommands = "Custom Commands"

        public var id: String { rawValue }
    }

    public private(set) var settings: AppSettings
    public var selectedTab: Tab = .general
    public private(set) var installation: Loadable<GitInstallation> = .idle
    public var name = ""
    public var email = ""
    public private(set) var savedIdentity: GitIdentity = .empty
    public private(set) var identityError: String?
    public private(set) var identityNotice: String?
    public private(set) var isSavingIdentity = false
    public private(set) var commandLineTool: CommandLineToolStatus?
    public private(set) var commandLineToolError: String?
    public private(set) var isInstallingCommandLineTool = false
    @ObservationIgnored public var onChange: (@MainActor (AppSettings) -> Void)?
    public let integration: IntegrationSettingsViewModel
    public let signing: SigningSettingsViewModel
    public let customCommands: CustomCommandsSettingsViewModel
    public let lessons = LessonBrowserViewModel()

    private let dependencies: SettingsDependencies

    public init(dependencies: SettingsDependencies) {
        self.dependencies = dependencies
        settings = dependencies.loadSettings.execute()
        integration = IntegrationSettingsViewModel(dependencies: dependencies.integration)
        signing = SigningSettingsViewModel(dependencies: dependencies.signing)
        customCommands = CustomCommandsSettingsViewModel(dependencies: dependencies.customCommands)
    }

    public var identityHasChanges: Bool {
        IdentityFields.trimmed(name) != (savedIdentity.name ?? "") || IdentityFields.trimmed(email) != (savedIdentity.email ?? "")
    }

    public func set<Value: Equatable>(_ keyPath: WritableKeyPath<AppSettings, Value>, to value: Value) {
        guard settings[keyPath: keyPath] != value else { return }
        var updated = settings
        updated[keyPath: keyPath] = value
        settings = dependencies.saveSettings.execute(updated)
        onChange?(settings)
    }

    public func load() async {
        installation = .loading
        do {
            installation = .loaded(try await dependencies.loadGitInstallation.execute())
        } catch {
            installation = .failed(error.localizedDescription)
        }
        do {
            show(try await dependencies.loadGlobalIdentity.execute())
            identityError = nil
        } catch {
            identityError = error.localizedDescription
        }
        await signing.load()
        commandLineTool = await dependencies.loadCommandLineTool.execute()
    }

    public func installCommandLineTool() async {
        guard !isInstallingCommandLineTool else { return }
        isInstallingCommandLineTool = true
        defer { isInstallingCommandLineTool = false }
        do {
            commandLineTool = try await dependencies.installCommandLineTool.execute()
            commandLineToolError = nil
        } catch {
            commandLineToolError = error.localizedDescription
        }
    }

    public func saveIdentity() async {
        guard !isSavingIdentity else { return }
        isSavingIdentity = true
        defer { isSavingIdentity = false }
        identityNotice = nil
        do {
            show(try await dependencies.saveGlobalIdentity.execute(name: name, email: email))
            identityError = nil
            identityNotice = "Saved with git config --global. New commits in every repository use this identity unless a repository sets its own."
        } catch {
            identityError = error.localizedDescription
        }
    }

    private func show(_ identity: GitIdentity) {
        savedIdentity = identity
        name = identity.name ?? ""
        email = identity.email ?? ""
    }
}

enum IdentityFields {
    static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
