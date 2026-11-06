import MorkDomain
import SwiftUI

struct SigningSettingsFields: View {
    @Bindable var viewModel: SigningSettingsViewModel
    let identifier: String

    var body: some View {
        Picker("Sign commits", selection: $viewModel.signsCommits) {
            Text(viewModel.signingNotSetTitle).tag(Bool?.none)
            Text("Yes").tag(Bool?.some(true))
            Text("No").tag(Bool?.some(false))
        }
        .accessibilityIdentifier("\(identifier).sign")
        Picker("Format", selection: $viewModel.format) {
            Text(viewModel.formatNotSetTitle).tag(SigningFormat?.none)
            ForEach(SigningFormat.allCases) { Text($0.title).tag(SigningFormat?.some($0)) }
        }
        .accessibilityIdentifier("\(identifier).format")
        HStack(spacing: Metrics.Spacing.s) {
            TextField("Signing key", text: $viewModel.key, prompt: Text(viewModel.keyPlaceholder))
                .accessibilityIdentifier("\(identifier).key")
            Menu {
                if viewModel.visibleKeys.isEmpty {
                    Text(viewModel.isLoadingKeys ? "Looking for keys…" : noKeysTitle)
                }
                ForEach(viewModel.visibleKeys) { key in
                    Button("\(key.title) — \(key.detail)") { viewModel.choose(key) }
                }
            } label: {
                Text("Choose")
            }
            .fixedSize()
            .accessibilityIdentifier("\(identifier).chooseKey")
        }
        if let warning = viewModel.missingKeyWarning {
            Label(warning, systemImage: "exclamationmark.triangle")
                .font(Metrics.Font.caption)
                .foregroundStyle(Palette.Status.conflict.ink.color)
                .accessibilityIdentifier("\(identifier).missingKey")
        }
        if let error = viewModel.error {
            SettingCaption(text: error, tone: .danger)
                .accessibilityIdentifier("\(identifier).error")
        }
        if let notice = viewModel.notice {
            caption(notice)
                .accessibilityIdentifier("\(identifier).notice")
        }
        HStack(alignment: .top) {
            caption(viewModel.isLocal
                ? "git config --local, only for this repository. \"Same as global\" removes the local value."
                : "git config --global commit.gpgsign, gpg.format and user.signingkey. SSH keys are listed from ~/.ssh (public keys only); gpg keys from gpg --list-secret-keys.")
            Spacer()
            Button("Save Signing") { Task { await viewModel.save() } }
                .buttonStyle(.morkSecondary)
                .disabled(!viewModel.hasChanges || viewModel.isSaving)
                .accessibilityIdentifier("\(identifier).save")
        }
    }

    private var noKeysTitle: String {
        viewModel.effectiveFormat == .ssh ? "No public keys in ~/.ssh" : "No gpg secret keys found (is gpg installed?)"
    }

    private func caption(_ text: String) -> some View {
        SettingCaption(text: text)
    }
}
