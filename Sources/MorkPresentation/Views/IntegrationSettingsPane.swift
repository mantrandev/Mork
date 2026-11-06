import AppKit
import MorkDomain
import SwiftUI

struct IntegrationSettingsPane: View {
    let viewModel: SettingsViewModel

    private var integration: IntegrationSettingsViewModel { viewModel.integration }
    private var tools: ExternalToolSettings { viewModel.settings.externalTools }
    private var apps: IntegrationSettings { viewModel.settings.integration }

    var body: some View {
        Form {
            Section("Terminal app") {
                choicePicker(
                    "Open repositories in",
                    selection: binding(get: { $0.integration.selection(for: .terminal) }, set: { $0.integration.terminal = $1 }),
                    choices: integration.appChoices(.terminal, selection: apps.selection(for: .terminal)),
                    allowsNone: false,
                    identifier: "settings.integration.terminal"
                )
                if apps.selection(for: .terminal) == ExternalToolSettings.customID {
                    commandField(\.integration.customTerminalCommand, prompt: #"open -a MyTerminal "$DIR""#, identifier: "settings.integration.terminalCommand")
                    SettingCaption(text: "Runs with /bin/sh. $DIR is the repository folder.")
                }
            }
            Section("External editor") {
                choicePicker(
                    "Open files in",
                    selection: binding(get: { $0.integration.editor }, set: { $0.integration.editor = $1 }),
                    choices: integration.appChoices(.editor, selection: apps.editor),
                    allowsNone: true,
                    identifier: "settings.integration.editor"
                )
                if apps.editor == ExternalToolSettings.customID {
                    commandField(\.integration.customEditorCommand, prompt: #"myeditor "$FILE":$LINE"#, identifier: "settings.integration.editorCommand")
                    SettingCaption(text: "Runs with /bin/sh. $FILE is the file or folder, $LINE the line (1 when there is none).")
                }
            }
            toolSection(.diff, title: "Diff tool", prompt: #"mytool "$LOCAL" "$REMOTE""#, note: "git difftool writes the old version to $LOCAL and the new one to $REMOTE.")
            toolSection(.merge, title: "Merge tool", prompt: #"mytool "$BASE" "$LOCAL" "$REMOTE" -o "$MERGED""#, note: "git mergetool passes $BASE (common ancestor), $LOCAL (ours), $REMOTE (theirs); the tool saves the result to $MERGED.") {
                Toggle("Trust exit code", isOn: binding(get: { $0.externalTools.trustsExitCode }, set: { $0.externalTools.trustsExitCode = $1 }))
                    .accessibilityIdentifier("settings.integration.trustExitCode")
                SettingCaption(text: "On: exit code 0 means resolved. Off: git checks whether the tool saved the file, and keeps the conflict when it did not.")
            }
            Section {
                HStack {
                    SettingCaption(text: "Mork looks in /Applications, ~/Applications and your PATH. It never starts an app to find it, and needs no command-line helper installed.")
                    Spacer()
                    if integration.isRescanning { ProgressView().controlSize(.small) }
                    Button("Rescan") { Task { await integration.rescan() } }
                        .buttonStyle(.morkSecondary)
                        .disabled(integration.isRescanning)
                        .accessibilityIdentifier("settings.integration.rescan")
                }
            }
        }
        .formStyle(.grouped)
        .task { await integration.load() }
    }

    @ViewBuilder
    private func toolSection(
        _ role: ExternalToolRole,
        title: String,
        prompt: String,
        note: String,
        @ViewBuilder extra: () -> some View = { EmptyView() }
    ) -> some View {
        let keyPath: WritableKeyPath<AppSettings, String?> = role == .merge ? \.externalTools.mergeTool : \.externalTools.diffTool
        let commandPath: WritableKeyPath<AppSettings, String> = role == .merge ? \.externalTools.customMergeCommand : \.externalTools.customDiffCommand
        Section(title) {
            choicePicker(
                role == .merge ? "Resolve conflicts with" : "Show diffs with",
                selection: binding(get: { $0[keyPath: keyPath] }, set: { $0[keyPath: keyPath] = $1 }),
                choices: integration.toolChoices(selection: tools.tool(for: role)),
                allowsNone: true,
                identifier: "settings.integration.\(role.rawValue)Tool"
            )
            if tools.tool(for: role) == ExternalToolSettings.customID {
                commandField(commandPath, prompt: prompt, identifier: "settings.integration.\(role.rawValue)Command")
                SettingCaption(text: note)
            }
            extra()
            HStack(alignment: .top) {
                if let check = integration.check(for: role, settings: tools) {
                    VStack(alignment: .leading, spacing: Metrics.Spacing.xs) {
                        Label(check.message, systemImage: check.isReady ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .foregroundStyle(check.isReady ? Palette.Status.added.ink.color : Palette.Status.deleted.ink.color)
                            .font(Metrics.Font.caption)
                            .fixedSize(horizontal: false, vertical: true)
                        if let command = check.command {
                            Text(command)
                                .font(Metrics.Font.monoCaption)
                                .foregroundStyle(Palette.Text.primary.color)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("settings.integration.\(role.rawValue)Check")
                }
                Spacer()
                Button("Test") { Task { await integration.test(role, settings: tools) } }
                    .buttonStyle(.morkSecondary)
                    .disabled(tools.tool(for: role) == nil)
                    .help("Check that the program exists and the command is complete. Nothing is started.")
                    .accessibilityIdentifier("settings.integration.\(role.rawValue)Test")
            }
        }
    }

    private func choicePicker(_ title: String, selection: Binding<String?>, choices: [IntegrationChoice], allowsNone: Bool, identifier: String) -> some View {
        Picker(title, selection: selection) {
            if allowsNone {
                Text("None").tag(String?.none)
            }
            ForEach(choices) { choice in
                Label {
                    Text(choice.name)
                } icon: {
                    if let icon = AppIcons.icon(atPath: choice.application) {
                        Image(nsImage: icon)
                    }
                }
                .tag(Optional(choice.id))
            }
            Divider()
            Text("Custom…").tag(Optional(ExternalToolSettings.customID))
        }
        .accessibilityIdentifier(identifier)
    }

    private func commandField(_ keyPath: WritableKeyPath<AppSettings, String>, prompt: String, identifier: String) -> some View {
        TextField("Command", text: binding(get: { $0[keyPath: keyPath] }, set: { $0[keyPath: keyPath] = $1 }), prompt: Text(prompt))
            .font(Metrics.Font.monoBody)
            .accessibilityIdentifier(identifier)
    }

    private func binding<Value: Equatable>(get: @escaping (AppSettings) -> Value, set: @escaping (inout AppSettings, Value) -> Void) -> Binding<Value> {
        Binding(
            get: { get(viewModel.settings) },
            set: { value in
                var updated = viewModel.settings
                set(&updated, value)
                viewModel.set(\.self, to: updated)
            }
        )
    }
}
