import MorkDomain
import Foundation
import Observation

@MainActor
@Observable
public final class SigningSettingsViewModel {
    public var signsCommits: Bool?
    public var format: SigningFormat? {
        didSet { if format != oldValue { updateVisibleKeys() } }
    }
    public var key = ""
    public private(set) var saved: SigningSettings = .empty
    public private(set) var inherited: SigningSettings?
    public private(set) var keys: [SigningKey] = []
    public private(set) var visibleKeys: [SigningKey] = []
    public private(set) var isLoadingKeys = false
    public private(set) var error: String?
    public private(set) var notice: String?
    public private(set) var isSaving = false

    private let dependencies: SigningSettingsDependencies

    public init(dependencies: SigningSettingsDependencies) {
        self.dependencies = dependencies
    }

    public var isLocal: Bool { dependencies.loadInherited != nil }

    public var current: SigningSettings {
        SigningSettings(signsCommits: signsCommits, format: format, key: IdentityFields.trimmed(key).isEmpty ? nil : IdentityFields.trimmed(key))
    }

    public var hasChanges: Bool { current != saved }

    public var effectiveFormat: SigningFormat {
        format ?? inherited?.format ?? .openpgp
    }

    public var signingNotSetTitle: String {
        guard isLocal else { return "Not set (off)" }
        return "Same as global (\(inherited?.signsCommits == true ? "on" : "off"))"
    }

    public var formatNotSetTitle: String {
        guard isLocal else { return "Not set (OpenPGP)" }
        return "Same as global (\((inherited?.format ?? .openpgp).title))"
    }

    public var keyPlaceholder: String {
        if isLocal, let key = inherited?.key { return "\(key) (global)" }
        return effectiveFormat == .ssh ? "~/.ssh/id_ed25519.pub" : "gpg key ID or fingerprint"
    }

    public var missingKeyWarning: String? {
        guard current.resolved(over: inherited ?? .empty).signsCommits == true,
              current.resolved(over: inherited ?? .empty).key == nil,
              effectiveFormat == .ssh
        else { return nil }
        return "SSH signing needs a signing key: pick your public key (.pub)."
    }

    public func load() async {
        do {
            show(try await dependencies.loadSettings.execute())
            inherited = try await dependencies.loadInherited?.execute()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        updateVisibleKeys()
        isLoadingKeys = true
        keys = await dependencies.loadKeys.execute()
        isLoadingKeys = false
        updateVisibleKeys()
    }

    public func choose(_ signingKey: SigningKey) {
        key = signingKey.value
        if effectiveFormat != signingKey.format { format = signingKey.format }
    }

    public func save() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        notice = nil
        do {
            show(try await dependencies.saveSettings.execute(current))
            error = nil
            let flag = isLocal ? "--local" : "--global"
            notice = "Saved with git config \(flag) commit.gpgsign, gpg.format and user.signingkey. Commits, amends, merges, cherry-picks, reverts and rebases sign through these settings."
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func show(_ settings: SigningSettings) {
        saved = settings
        signsCommits = settings.signsCommits
        format = settings.format
        key = settings.key ?? ""
    }

    private func updateVisibleKeys() {
        let format = effectiveFormat
        let filtered = keys.filter { $0.format == format }
        if visibleKeys != filtered { visibleKeys = filtered }
    }
}
