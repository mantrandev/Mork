import MorkDomain
import SwiftUI

struct RepositorySettingsSheet: View {
    @Bindable var session: RepositorySettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Sheet.sectionSpacing) {
            DialogHeader(kind: .form, glyph: "gearshape", title: "Repository Settings")
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.Sheet.sectionSpacing) {
                    identity
                    Hairline()
                    commitTemplate
                    Hairline()
                    signing
                    Hairline()
                    remotes
                    Hairline()
                    gitignore
                }
                .padding(.horizontal, Metrics.Spacing.xxs)
            }
            .frame(minHeight: Metrics.Sheet.scrollMinimumHeight, idealHeight: Metrics.Sheet.scrollIdealHeight)
            DialogButtonRow {
                Button("Done") { dismiss() }
                    .buttonStyle(.morkPrimary)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("repoSettings.done")
            }
        }
        .padding(Metrics.Sheet.padding)
        .frame(width: Metrics.Sheet.wideWidth)
        .dialogSurface()
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: Metrics.Sheet.rowSpacing) {
            sectionTitle("Identity for this repository")
            DialogLabeledRow("Name") {
                DialogTextField(placeholder: "Name", text: $session.name, prompt: session.namePlaceholder, identifier: "repoSettings.name")
            }
            DialogLabeledRow("Email") {
                DialogTextField(placeholder: "Email", text: $session.email, prompt: session.emailPlaceholder, identifier: "repoSettings.email")
            }
            if let error = session.identityError {
                DialogNote(text: error, tone: .danger)
                    .accessibilityIdentifier("repoSettings.identityError")
            }
            if let notice = session.identityNotice {
                DialogNote(text: notice)
                    .accessibilityIdentifier("repoSettings.identityNotice")
            }
            HStack(alignment: .top) {
                DialogNote(text: "git config --local writes .git/config. A value here wins over the global one for commits in this repository; leave a field empty to use the global value.")
                Spacer()
                Button("Save Identity") { Task { await session.saveIdentity() } }
                    .buttonStyle(.morkSecondary)
                    .disabled(!session.identityHasChanges || session.isSaving)
                    .accessibilityIdentifier("repoSettings.saveIdentity")
            }
        }
    }

    private var commitTemplate: some View {
        VStack(alignment: .leading, spacing: Metrics.Sheet.rowSpacing) {
            sectionTitle("Commit template")
            DialogTextField(placeholder: "Template file", text: $session.commitTemplatePath, prompt: session.templatePlaceholder, identifier: "repoSettings.commitTemplate", isMonospaced: true)
            if let error = session.templateError {
                DialogNote(text: error, tone: .danger)
                    .accessibilityIdentifier("repoSettings.templateError")
            }
            if let notice = session.templateNotice {
                DialogNote(text: notice)
                    .accessibilityIdentifier("repoSettings.templateNotice")
            }
            HStack(alignment: .top) {
                DialogNote(text: "git config --local commit.template. A path relative to the repository root, absolute, or starting with ~/. Its text fills an empty commit message; lines starting with # are dropped when you commit. Leave empty to use the global template.")
                Spacer()
                Button("Save Template") { Task { await session.saveCommitTemplate() } }
                    .buttonStyle(.morkSecondary)
                    .disabled(!session.templateHasChanges || session.isSaving)
                    .accessibilityIdentifier("repoSettings.saveTemplate")
            }
        }
    }

    private var signing: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.s) {
            sectionTitle("Commit signing for this repository")
            SigningSettingsFields(viewModel: session.signing, identifier: "repoSettings.signing")
        }
    }

    private var remotes: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.s) {
            sectionTitle("Remotes")
            if session.remotes.isEmpty {
                DialogNote(text: "No remotes yet.")
                    .accessibilityIdentifier("repoSettings.noRemotes")
            }
            ForEach(session.remotes) { remote in
                VStack(alignment: .leading, spacing: Metrics.Spacing.xxs) {
                    Text(remote.name).font(Metrics.Font.title.weight(.medium)).foregroundStyle(Palette.Text.primary.color)
                    Text(remote.fetchURL).font(Metrics.Font.monoCaption).foregroundStyle(Palette.Text.secondary.color).textSelection(.enabled)
                    if let push = remote.pushURL {
                        Text("push: \(push)").font(Metrics.Font.monoCaption).foregroundStyle(Palette.Text.secondary.color).textSelection(.enabled)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel([remote.name, remote.fetchURL, remote.pushURL.map { "push: \($0)" }].compactMap { $0 }.joined(separator: ", "))
                .accessibilityIdentifier("repoSettings.remote.\(remote.name)")
            }
            DialogNote(text: "Add, rename or remove remotes in the sidebar under Remotes (+ button or right-click).")
                .accessibilityIdentifier("repoSettings.remotesHint")
        }
    }

    private var gitignore: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.s) {
            sectionTitle(".gitignore")
            DialogTextEditor(placeholder: "", text: $session.ignoreText, height: Metrics.Sheet.ignoreEditorHeight, identifier: "repoSettings.gitignore", isMonospaced: true)
            if let error = session.ignoreError {
                DialogNote(text: error, tone: .danger)
                    .accessibilityIdentifier("repoSettings.ignoreError")
            }
            if let notice = session.ignoreNotice {
                DialogNote(text: notice)
                    .accessibilityIdentifier("repoSettings.ignoreNotice")
            }
            HStack(alignment: .top) {
                DialogNote(text: "One pattern per line. # starts a comment, a trailing / matches folders only, ! re-includes a path. Files Git already tracks stay tracked.")
                Spacer()
                Button(session.ignoreSaveTitle) { Task { await session.saveIgnoreFile() } }
                    .buttonStyle(.morkSecondary)
                    .disabled(!session.ignoreHasChanges || session.isSaving)
                    .accessibilityIdentifier("repoSettings.saveGitignore")
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(Metrics.Font.title.weight(.semibold))
            .foregroundStyle(Palette.Text.primary.color)
    }
}

extension View {
    func repositorySettingsPresentation(_ viewModel: RepositoryViewModel) -> some View {
        modifier(RepositorySettingsPresentation(viewModel: viewModel))
    }
}

private struct RepositorySettingsPresentation: ViewModifier {
    @Bindable var viewModel: RepositoryViewModel

    func body(content: Content) -> some View {
        content
            .sheet(item: $viewModel.repositorySettings) { RepositorySettingsSheet(session: $0) }
            .environment(\.diffMetrics, DiffMetrics(fontSize: CGFloat(viewModel.settings.diff.fontSize), tabWidth: viewModel.settings.diff.tabWidth))
    }
}
