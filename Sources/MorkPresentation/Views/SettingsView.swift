import MorkDomain
import SwiftUI

public struct SettingsView: View {
    @Bindable private var viewModel: SettingsViewModel
    private let accounts: AccountsViewModel
    private let sshKeys: SSHKeysViewModel

    public init(viewModel: SettingsViewModel, accounts: AccountsViewModel, sshKeys: SSHKeysViewModel) {
        self.viewModel = viewModel
        self.accounts = accounts
        self.sshKeys = sshKeys
    }

    public var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            GeneralSettingsPane(viewModel: viewModel)
                .settingsPane(.general)
                .tabItem { Label(SettingsViewModel.Tab.general.rawValue, systemImage: "gearshape") }
                .tag(SettingsViewModel.Tab.general)
            GitSettingsPane(viewModel: viewModel)
                .settingsPane(.git)
                .tabItem { Label(SettingsViewModel.Tab.git.rawValue, systemImage: "terminal") }
                .tag(SettingsViewModel.Tab.git)
            DiffSettingsPane(viewModel: viewModel)
                .settingsPane(.diff)
                .tabItem { Label(SettingsViewModel.Tab.diff.rawValue, systemImage: "plusminus") }
                .tag(SettingsViewModel.Tab.diff)
            LearningSettingsPane(viewModel: viewModel)
                .settingsPane(.learning)
                .tabItem { Label(SettingsViewModel.Tab.learning.rawValue, systemImage: "graduationcap") }
                .tag(SettingsViewModel.Tab.learning)
            AccountsSettingsPane(viewModel: accounts)
                .settingsPane(.accounts)
                .tabItem { Label(SettingsViewModel.Tab.accounts.rawValue, systemImage: "person.crop.circle") }
                .tag(SettingsViewModel.Tab.accounts)
            SSHSettingsPane(viewModel: sshKeys)
                .settingsPane(.ssh)
                .tabItem { Label(SettingsViewModel.Tab.ssh.rawValue, systemImage: "key") }
                .tag(SettingsViewModel.Tab.ssh)
            IntegrationSettingsPane(viewModel: viewModel)
                .settingsPane(.integration)
                .tabItem { Label(SettingsViewModel.Tab.integration.rawValue, systemImage: "app.connected.to.app.below.fill") }
                .tag(SettingsViewModel.Tab.integration)
            CustomCommandsSettingsPane(viewModel: viewModel.customCommands)
                .settingsPane(.customCommands)
                .tabItem { Label(SettingsViewModel.Tab.customCommands.rawValue, systemImage: "command") }
                .tag(SettingsViewModel.Tab.customCommands)
        }
        .task { await viewModel.load() }
    }
}

struct SettingCaption: View {
    let text: String
    var tone: DialogNote.Tone = .secondary

    var body: some View {
        Text(text)
            .font(Metrics.Font.caption)
            .foregroundStyle(tone.color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private extension SettingsViewModel {
    func binding<Value: Equatable>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(get: { self.settings[keyPath: keyPath] }, set: { self.set(keyPath, to: $0) })
    }
}

struct GeneralSettingsPane: View {
    let viewModel: SettingsViewModel

    var body: some View {
        Form {
            Picker("Default pull mode", selection: viewModel.binding(\.defaultPullMode)) {
                ForEach(PullMode.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .accessibilityIdentifier("settings.pullMode")
            SettingCaption(text: "Preselected in Pull… for repositories where you never picked a mode. \(viewModel.settings.defaultPullMode.explanation)")
            Picker("Fetch automatically", selection: viewModel.binding(\.autoFetch)) {
                ForEach(AutoFetchInterval.allCases) { Text($0.title).tag($0) }
            }
            .accessibilityIdentifier("settings.autoFetch")
            SettingCaption(text: "Runs git fetch --prune for the open repository only, and never while another action is running.")
            Toggle("Confirm before discarding changes or resetting --hard", isOn: viewModel.binding(\.confirmsDestructiveActions))
                .accessibilityIdentifier("settings.confirmDestructive")
            Toggle("Show Git Console on launch", isOn: viewModel.binding(\.showsConsoleOnLaunch))
                .accessibilityIdentifier("settings.consoleOnLaunch")
            SettingCaption(text: "When off, the console starts hidden. When on, it opens the way you left it.")
            Toggle("Show author avatars", isOn: viewModel.binding(\.showsAuthorAvatars))
                .accessibilityIdentifier("settings.authorAvatars")
            SettingCaption(text: "Author emails are sent to GitHub and Gravatar to fetch avatars. When off, only initials show.")
            CommandLineToolSection(viewModel: viewModel)
        }
        .formStyle(.grouped)
    }
}

struct CommandLineToolSection: View {
    let viewModel: SettingsViewModel

    var body: some View {
        let row = CommandLineToolPresentation(viewModel.commandLineTool)
        Section("Command line tool") {
            HStack {
                LabeledContent("Status", value: row.summary)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("settings.cli.status")
                Spacer()
                Button(row.buttonTitle) { Task { await viewModel.installCommandLineTool() } }
                    .buttonStyle(.morkSecondary)
                    .disabled(!row.canInstall || viewModel.isInstallingCommandLineTool)
                    .accessibilityIdentifier("settings.cli.install")
            }
            if let error = viewModel.commandLineToolError {
                SettingCaption(text: error, tone: .danger)
                    .accessibilityIdentifier("settings.cli.error")
            }
            SettingCaption(text: row.caption)
        }
    }
}

struct GitSettingsPane: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Git in use") {
                switch viewModel.installation {
                case .idle, .loading:
                    ProgressView().controlSize(.small)
                case let .loaded(installation):
                    LabeledContent("Executable", value: installation.path ?? "git (found through PATH)")
                        .textSelection(.enabled)
                        .accessibilityIdentifier("settings.git.path")
                    LabeledContent("Version", value: installation.version)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("settings.git.version")
                case let .failed(message):
                    Text(message)
                        .font(Metrics.Font.title)
                        .foregroundStyle(Palette.Status.deleted.ink.color)
                        .accessibilityIdentifier("settings.git.versionError")
                }
                SettingCaption(text: "Read with git --version. Mork runs this git for every command.")
            }
            Section("Global identity") {
                TextField("Name", text: $viewModel.name, prompt: Text("Your Name"))
                    .accessibilityIdentifier("settings.git.name")
                TextField("Email", text: $viewModel.email, prompt: Text("Email for commits"))
                    .accessibilityIdentifier("settings.git.email")
                if let error = viewModel.identityError {
                    SettingCaption(text: error, tone: .danger)
                        .accessibilityIdentifier("settings.git.error")
                }
                if let notice = viewModel.identityNotice {
                    SettingCaption(text: notice)
                        .accessibilityIdentifier("settings.git.notice")
                }
                HStack {
                    SettingCaption(text: "git config --global user.name and user.email, stored in ~/.gitconfig. Every commit records them as author.")
                    Spacer()
                    Button("Save") { Task { await viewModel.saveIdentity() } }
                        .buttonStyle(.morkSecondary)
                        .disabled(!viewModel.identityHasChanges || viewModel.isSavingIdentity)
                        .accessibilityIdentifier("settings.git.save")
                }
            }
            Section("Commit signing") {
                SigningSettingsFields(viewModel: viewModel.signing, identifier: "settings.signing")
            }
        }
        .formStyle(.grouped)
    }
}

struct DiffSettingsPane: View {
    let viewModel: SettingsViewModel

    var body: some View {
        Form {
            Stepper(value: viewModel.binding(\.diff.fontSize), in: DiffSettings.fontSizes) {
                LabeledContent("Font size", value: "\(viewModel.settings.diff.fontSize) pt")
            }
            .accessibilityIdentifier("settings.diff.fontSize")
            Picker("Tab width", selection: viewModel.binding(\.diff.tabWidth)) {
                ForEach(DiffSettings.tabWidths, id: \.self) { Text("\($0) spaces").tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings.diff.tabWidth")
            Toggle("Show whitespace changes", isOn: viewModel.binding(\.diff.showsWhitespaceChanges))
                .accessibilityIdentifier("settings.diff.whitespace")
            SettingCaption(text: "Off adds -w to History diffs so indentation-only changes disappear. Changes always shows whitespace, because staging a hunk or line needs the exact patch.")
            Stepper(value: viewModel.binding(\.diff.contextLines), in: DiffSettings.contextLineRange) {
                LabeledContent("Context lines", value: "\(viewModel.settings.diff.contextLines)")
            }
            .accessibilityIdentifier("settings.diff.context")
            SettingCaption(text: "Unchanged lines around each change, passed as -U\(viewModel.settings.diff.contextLines). Changes uses at least 1, because git apply needs context to stage a hunk or line.")
        }
        .formStyle(.grouped)
    }
}

struct LearningSettingsPane: View {
    let viewModel: SettingsViewModel

    var body: some View {
        Form {
            Toggle("Show a lesson under each console entry", isOn: viewModel.binding(\.showsLessons))
                .accessibilityIdentifier("settings.learning.lessons")
            Toggle("Show read commands in the console by default", isOn: viewModel.binding(\.showsReadCommands))
                .accessibilityIdentifier("settings.learning.readCommands")
            SettingCaption(text: "Read commands (status, log, diff…) only look at the repository. Write commands change it. The console toggle still switches them for this session.")
            Section {
                LessonBrowserView(viewModel: viewModel.lessons)
                    .frame(height: Metrics.Lesson.browserHeight)
            } header: {
                Text("Browse lessons")
            } footer: {
                SettingCaption(text: "Every lesson the Git Console can show, without running a command.")
            }
        }
        .formStyle(.grouped)
    }
}
