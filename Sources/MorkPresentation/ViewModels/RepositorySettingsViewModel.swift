import MorkDomain
import Foundation
import Observation

@MainActor
@Observable
public final class RepositorySettingsViewModel: Identifiable {
    public nonisolated let id = UUID()
    public let remotes: [Remote]
    public var name = ""
    public var email = ""
    public var ignoreText = ""
    public private(set) var localIdentity: GitIdentity = .empty
    public private(set) var globalIdentity: GitIdentity = .empty
    public private(set) var ignoreDocument: IgnoreFileDocument?
    public private(set) var identityError: String?
    public private(set) var identityNotice: String?
    public private(set) var ignoreError: String?
    public private(set) var ignoreNotice: String?
    public private(set) var isSaving = false
    public var commitTemplatePath = ""
    public private(set) var localCommitTemplate: String?
    public private(set) var globalCommitTemplate: String?
    public private(set) var templateError: String?
    public private(set) var templateNotice: String?
    public let signing: SigningSettingsViewModel

    private let dependencies: RepositorySettingsDependencies
    private let onIgnoreSaved: @MainActor () async -> Void
    private let onCommitTemplateSaved: @MainActor () async -> Void

    public init(
        remotes: [Remote],
        dependencies: RepositorySettingsDependencies,
        onIgnoreSaved: @escaping @MainActor () async -> Void,
        onCommitTemplateSaved: @escaping @MainActor () async -> Void = {}
    ) {
        self.remotes = remotes
        self.dependencies = dependencies
        self.onIgnoreSaved = onIgnoreSaved
        self.onCommitTemplateSaved = onCommitTemplateSaved
        signing = SigningSettingsViewModel(dependencies: dependencies.signing)
    }

    public var identityHasChanges: Bool {
        IdentityFields.trimmed(name) != (localIdentity.name ?? "") || IdentityFields.trimmed(email) != (localIdentity.email ?? "")
    }

    public var ignoreHasChanges: Bool {
        ignoreDocument?.hasChanges(ignoreText) ?? false
    }

    public var ignoreSaveTitle: String {
        ignoreDocument?.exists == false ? "Create .gitignore" : "Save .gitignore"
    }

    public var templateHasChanges: Bool {
        IdentityFields.trimmed(commitTemplatePath) != (localCommitTemplate ?? "")
    }

    public var templatePlaceholder: String { Self.placeholder(globalCommitTemplate) }

    public var namePlaceholder: String { Self.placeholder(globalIdentity.name) }
    public var emailPlaceholder: String { Self.placeholder(globalIdentity.email) }

    public func load() async {
        do {
            showLocal(try await dependencies.loadLocalIdentity.execute())
            globalIdentity = try await dependencies.loadGlobalIdentity.execute()
            identityError = nil
        } catch {
            identityError = error.localizedDescription
        }
        do {
            localCommitTemplate = try await dependencies.loadLocalCommitTemplate.execute()
            commitTemplatePath = localCommitTemplate ?? ""
            globalCommitTemplate = try await dependencies.loadGlobalCommitTemplate.execute()
            templateError = nil
        } catch {
            templateError = error.localizedDescription
        }
        do {
            let document = try await dependencies.loadIgnoreFile.execute()
            ignoreDocument = document
            ignoreText = document.text
            ignoreError = nil
        } catch {
            ignoreError = error.localizedDescription
        }
        await signing.load()
    }

    public func saveIdentity() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        identityNotice = nil
        do {
            let saved = try await dependencies.saveLocalIdentity.execute(name: name, email: email)
            showLocal(saved)
            identityError = nil
            identityNotice = saved == .empty
                ? "Removed with git config --local --unset. This repository uses your global identity again."
                : "Saved with git config --local. Only commits in this repository use it; empty fields fall back to your global identity."
        } catch {
            identityError = error.localizedDescription
        }
    }

    public func saveCommitTemplate() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        templateNotice = nil
        do {
            let saved = try await dependencies.saveLocalCommitTemplate.execute(commitTemplatePath)
            localCommitTemplate = saved
            commitTemplatePath = saved ?? ""
            templateError = nil
            templateNotice = saved == nil
                ? "Removed with git config --local --unset commit.template. The global template applies again, if you have one."
                : "Saved with git config --local commit.template. An empty commit message box now starts with this file's text."
            await onCommitTemplateSaved()
        } catch {
            templateError = error.localizedDescription
        }
    }

    public func saveIgnoreFile() async {
        guard !isSaving, let document = ignoreDocument else { return }
        isSaving = true
        defer { isSaving = false }
        ignoreNotice = nil
        do {
            let saved = try await dependencies.saveIgnoreFile.execute(text: ignoreText, document: document)
            ignoreDocument = saved
            ignoreText = saved.text
            ignoreError = nil
            ignoreNotice = "Saved .gitignore. Commit it so everyone who clones the repository ignores the same files."
            await onIgnoreSaved()
        } catch {
            ignoreError = error.localizedDescription
        }
    }

    private func showLocal(_ identity: GitIdentity) {
        localIdentity = identity
        name = identity.name ?? ""
        email = identity.email ?? ""
    }

    private static func placeholder(_ global: String?) -> String {
        global.map { "\($0) (global)" } ?? "Not set"
    }
}
