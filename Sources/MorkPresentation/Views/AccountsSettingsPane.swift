import MorkDomain
import SwiftUI

struct AccountsSettingsPane: View {
    @Bindable var viewModel: AccountsViewModel
    @Environment(\.openURL) private var openURL
    @State private var pendingRemoval: Account?

    var body: some View {
        Form {
            Section("Accounts") {
                if viewModel.entries.isEmpty {
                    Text("No accounts yet. Add one below to clone, fetch and push over https without a password prompt.")
                        .font(Metrics.Font.title)
                        .foregroundStyle(Palette.Text.secondary.color)
                        .accessibilityIdentifier("accounts.empty")
                }
                ForEach(viewModel.entries) { entry in
                    AccountRow(entry: entry, viewModel: viewModel) { pendingRemoval = entry.account }
                }
            }
            Section("Add account") {
                Picker("Service", selection: $viewModel.provider) {
                    ForEach(AccountProvider.allCases) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("accounts.provider")
                if viewModel.showsAddress {
                    TextField("Server", text: $viewModel.address, prompt: Text(viewModel.provider.defaultHost.map { "https://\($0)" } ?? "https://git.example.com"))
                        .accessibilityIdentifier("accounts.address")
                }
                if viewModel.showsUsername {
                    TextField("Email or username", text: $viewModel.username, prompt: Text("Atlassian email, or Bitbucket username for an app password"))
                        .accessibilityIdentifier("accounts.username")
                }
                SecureField(viewModel.secretTitle, text: $viewModel.token)
                    .accessibilityIdentifier("accounts.token")
                SettingCaption(text: viewModel.provider.scopeHint)
                    .accessibilityIdentifier("accounts.scopeHint")
                HStack {
                    if let url = viewModel.tokenPageURL {
                        Link("Create a token on \(url.host ?? "the website")…", destination: url)
                            .font(Metrics.Font.title)
                            .foregroundStyle(Palette.Accent.text.color)
                            .accessibilityIdentifier("accounts.tokenLink")
                    }
                    Spacer()
                    if viewModel.isSigningIn { ProgressView().controlSize(.small) }
                    if viewModel.canUseBrowserSignIn {
                        Button("Sign in with Browser") { viewModel.startBrowserSignIn() }
                            .buttonStyle(.morkSecondary)
                            .disabled(viewModel.deviceFlow != .idle && !isFailed)
                            .accessibilityIdentifier("accounts.browserSignIn")
                    }
                    Button("Sign In") { Task { await viewModel.signIn() } }
                        .buttonStyle(.morkPrimary)
                        .keyboardShortcut(.defaultAction)
                        .disabled(!viewModel.canSignIn)
                        .accessibilityIdentifier("accounts.signIn")
                }
                deviceFlow
                if let error = viewModel.errorMessage {
                    SettingCaption(text: error, tone: .danger)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("accounts.error")
                }
                if let notice = viewModel.notice {
                    SettingCaption(text: notice)
                        .accessibilityIdentifier("accounts.notice")
                }
            }
            Section("Sign in with browser (optional)") {
                TextField("GitHub OAuth client ID", text: $viewModel.githubClientID, prompt: Text("Iv1.…"))
                    .accessibilityIdentifier("accounts.githubClientID")
                TextField("GitLab application ID", text: $viewModel.gitlabClientID)
                    .accessibilityIdentifier("accounts.gitlabClientID")
                HStack {
                    SettingCaption(text: "Register your own OAuth app with device flow enabled, then paste its client ID. Without one, sign in with a token.")
                    Spacer()
                    Button("Save") { viewModel.saveClientIDs() }
                        .buttonStyle(.morkSecondary)
                        .accessibilityIdentifier("accounts.saveClientIDs")
                }
            }
            Section("How Mork uses an account") {
                SettingCaption(text: viewModel.lesson)
                    .accessibilityIdentifier("accounts.lesson")
            }
        }
        .formStyle(.grouped)
        .task { await viewModel.load() }
        .morkConfirmation(item: $pendingRemoval) { account in
            MorkConfirmation(
                kind: .destructive,
                glyph: "person.crop.circle.badge.minus",
                title: "Remove \(account.login)?",
                message: "Mork deletes the token of \(account.login) on \(account.server.displayName) from your Keychain. The token stays valid on the server until you revoke it there; sign in again to add the account back.",
                actions: [DialogAction(title: "Remove Account", isDestructive: true, identifier: "accounts.confirmRemove") { Task { await viewModel.remove(account) } }]
            )
        }
    }

    private var isFailed: Bool {
        if case .failed = viewModel.deviceFlow { return true }
        return false
    }

    @ViewBuilder
    private var deviceFlow: some View {
        switch viewModel.deviceFlow {
        case .idle:
            EmptyView()
        case .requesting:
            ProgressView("Asking for a sign-in code…")
                .controlSize(.small)
                .font(Metrics.Font.caption)
                .foregroundStyle(Palette.Text.secondary.color)
        case let .waiting(userCode, verificationURL):
            VStack(alignment: .leading, spacing: Metrics.ChangeRow.gap) {
                Text("Enter this code in the browser, then come back:")
                    .font(Metrics.Font.caption)
                    .foregroundStyle(Palette.Text.secondary.color)
                Text(userCode)
                    .font(Metrics.Font.display.monospaced())
                    .foregroundStyle(Palette.Text.primary.color)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("accounts.deviceCode")
                HStack {
                    Button("Open \(verificationURL.host ?? "browser")") { openURL(verificationURL) }
                        .buttonStyle(.morkPrimary)
                        .accessibilityIdentifier("accounts.openVerification")
                    Button("Cancel") { viewModel.cancelBrowserSignIn() }
                        .buttonStyle(.morkSecondary)
                        .accessibilityIdentifier("accounts.cancelBrowserSignIn")
                    ProgressView().controlSize(.small)
                }
            }
        case let .failed(message):
            SettingCaption(text: message, tone: .danger)
                .accessibilityIdentifier("accounts.deviceError")
        }
    }
}

private struct AccountRow: View {
    let entry: AccountEntry
    let viewModel: AccountsViewModel
    let remove: () -> Void

    var body: some View {
        HStack(spacing: Metrics.Spacing.m) {
            AvatarImage(id: entry.id, size: Metrics.Icon.avatar) { await viewModel.avatar(for: entry.account) }
            VStack(alignment: .leading, spacing: Metrics.Spacing.xxs) {
                Text(entry.account.displayName)
                    .font(Metrics.Font.title.weight(.semibold))
                    .foregroundStyle(Palette.Text.primary.color)
                Text("\(entry.account.login) · \(entry.account.provider.title) · \(entry.account.server.displayName)")
                    .font(Metrics.Font.caption)
                    .foregroundStyle(Palette.Text.secondary.color)
            }
            Spacer()
            if entry.status == .needsSignIn {
                Label("Needs sign-in", systemImage: "exclamationmark.triangle.fill")
                    .labelStyle(.titleAndIcon)
                    .font(Metrics.Font.caption)
                    .foregroundStyle(Palette.Status.conflict.ink.color)
                    .accessibilityIdentifier("accounts.needsSignIn.\(entry.account.login)")
                Button("Sign In Again") { viewModel.prepareSignIn(again: entry.account) }
                    .buttonStyle(.morkSecondary)
                    .accessibilityIdentifier("accounts.signInAgain.\(entry.account.login)")
            }
            Button("Remove", role: .destructive, action: remove)
                .buttonStyle(.morkDestructive)
                .accessibilityIdentifier("accounts.remove.\(entry.account.login)")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("accounts.row.\(entry.account.login)")
    }
}
