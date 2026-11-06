import MorkDomain
import SwiftUI

struct SSHSettingsPane: View {
    @Bindable var viewModel: SSHKeysViewModel
    @State private var directoryText = ""

    var body: some View {
        Form {
            Section("Keys") {
                HStack {
                    TextField("Folder", text: $directoryText)
                        .accessibilityIdentifier("ssh.directory")
                        .onSubmit { Task { await viewModel.useDirectory(directoryText) } }
                    Button("Choose…") {
                        if let url = FolderPicker.pick(prompt: "Choose") {
                            directoryText = url.path
                            Task { await viewModel.useDirectory(url.path) }
                        }
                    }
                    .buttonStyle(.morkSecondary)
                    Button("Reload") { Task { await viewModel.useDirectory(directoryText) } }
                        .buttonStyle(.morkSecondary)
                        .accessibilityIdentifier("ssh.reload")
                }
                keyList
            }
            if let key = viewModel.selectedKey {
                Section("Selected key") {
                    LabeledContent("Fingerprint") {
                        Text(key.fingerprint)
                            .font(Metrics.Font.monoCaption)
                            .foregroundStyle(Palette.Text.primary.color)
                            .textSelection(.enabled)
                    }
                    .accessibilityIdentifier("ssh.fingerprint")
                    HStack {
                        Button("Copy Public Key") { Task { await viewModel.copyPublicKey(key) } }
                            .buttonStyle(.morkSecondary)
                            .accessibilityIdentifier("ssh.copy")
                        Menu("Add to Account") {
                            ForEach(viewModel.uploadTargets) { account in
                                Button("\(account.login) on \(account.server.displayName)") { Task { await viewModel.add(key, to: account) } }
                            }
                        }
                        .disabled(viewModel.uploadTargets.isEmpty)
                        .fixedSize()
                        .accessibilityIdentifier("ssh.addToAccount")
                    }
                    HStack {
                        TextField("Host", text: $viewModel.testHost)
                            .accessibilityIdentifier("ssh.testHost")
                        Button("Test Connection") { Task { await viewModel.testConnection(with: key) } }
                            .buttonStyle(.morkSecondary)
                            .disabled(viewModel.isTesting)
                            .accessibilityIdentifier("ssh.test")
                        if viewModel.isTesting { ProgressView().controlSize(.small) }
                    }
                    SettingCaption(text: "Runs ssh -T -o BatchMode=yes -o StrictHostKeyChecking=accept-new git@\(viewModel.testHost) with this key only. accept-new trusts a host the first time and refuses one whose key changed.")
                    if let result = viewModel.connectionResult {
                        Label(result.message, systemImage: result.succeeded ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .font(Metrics.Font.title)
                            .foregroundStyle(result.succeeded ? Palette.Status.added.ink.color : Palette.Status.deleted.ink.color)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("ssh.testResult")
                    }
                }
            }
            Section("New ed25519 key") {
                TextField("File name", text: $viewModel.newKeyName)
                    .accessibilityIdentifier("ssh.newName")
                TextField("Email (comment)", text: $viewModel.email, prompt: Text("Email used as the key comment"))
                    .accessibilityIdentifier("ssh.newEmail")
                SecureField("Passphrase (optional)", text: $viewModel.passphrase)
                    .accessibilityIdentifier("ssh.newPassphrase")
                SecureField("Repeat passphrase", text: $viewModel.confirmation)
                    .accessibilityIdentifier("ssh.newPassphraseConfirm")
                HStack {
                    Text("ssh-keygen -t ed25519 -C \(viewModel.email.isEmpty ? "<email>" : viewModel.email) -f \(viewModel.directoryPath)/\(viewModel.newKeyName)")
                        .font(Metrics.Font.monoCaption)
                        .foregroundStyle(Palette.Text.secondary.color)
                        .textSelection(.enabled)
                    Spacer()
                    if viewModel.isGenerating { ProgressView().controlSize(.small) }
                    Button("Generate") { Task { await viewModel.generate() } }
                        .buttonStyle(.morkSecondary)
                        .disabled(!viewModel.canGenerate)
                        .accessibilityIdentifier("ssh.generate")
                }
                if !viewModel.passphrasesMatch {
                    SettingCaption(text: "The passphrases do not match.", tone: .danger)
                }
            }
            if let error = viewModel.errorMessage {
                SettingCaption(text: error, tone: .danger)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("ssh.error")
            }
            if let notice = viewModel.notice {
                SettingCaption(text: notice)
                    .accessibilityIdentifier("ssh.notice")
            }
            Section("How SSH keys work") {
                ForEach(viewModel.lessons, id: \.self) { lesson in
                    SettingCaption(text: lesson)
                }
            }
        }
        .formStyle(.grouped)
        .task {
            directoryText = viewModel.directoryPath
            await viewModel.accounts.load()
            await viewModel.load()
        }
    }

    @ViewBuilder
    private var keyList: some View {
        switch viewModel.keys {
        case .idle, .loading:
            ProgressView().controlSize(.small)
        case let .failed(message):
            Text(message)
                .font(Metrics.Font.title)
                .foregroundStyle(Palette.Status.deleted.ink.color)
        case let .loaded(keys) where keys.isEmpty:
            Text("No public keys (*.pub) in this folder. Generate one below.")
                .font(Metrics.Font.title)
                .foregroundStyle(Palette.Text.secondary.color)
                .accessibilityIdentifier("ssh.empty")
        case let .loaded(keys):
            Picker("Key", selection: $viewModel.selectedKeyID) {
                ForEach(keys) { key in
                    KeyRow(key: key).tag(Optional(key.id))
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            .accessibilityIdentifier("ssh.keys")
        }
    }
}

private struct KeyRow: View {
    let key: SSHKey

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.xxs) {
            HStack(spacing: Metrics.ChangeRow.gap) {
                Text(key.name)
                    .font(Metrics.Font.monoBody)
                    .foregroundStyle(Palette.Text.primary.color)
                Text([key.type, key.bits.map(String.init)].compactMap { $0 }.joined(separator: " "))
                    .font(Metrics.Font.caption)
                    .foregroundStyle(Palette.Text.secondary.color)
                if !key.hasPrivateKey {
                    Label("no private key", systemImage: "exclamationmark.triangle")
                        .font(Metrics.Font.caption)
                        .foregroundStyle(Palette.Status.conflict.ink.color)
                }
            }
            Text(key.comment.isEmpty ? key.fingerprint : "\(key.comment) · \(key.fingerprint)")
                .font(Metrics.Font.monoCaption)
                .foregroundStyle(Palette.Text.secondary.color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("ssh.key.\(key.name)")
    }
}
