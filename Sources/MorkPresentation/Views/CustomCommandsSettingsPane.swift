import MorkDomain
import SwiftUI

struct CustomCommandsSettingsPane: View {
    @Bindable var viewModel: CustomCommandsSettingsViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                List(selection: $viewModel.selectedID) {
                    ForEach(viewModel.commands) { command in
                        Text(command.name.isEmpty ? "Untitled" : command.name)
                            .font(Metrics.Font.title)
                            .foregroundStyle(command.name.isEmpty ? Palette.Text.secondary.color : Palette.Text.primary.color)
                            .lineLimit(1)
                            .frame(height: Metrics.Row.list)
                            .tag(command.id)
                            .accessibilityIdentifier("customCommands.row.\(command.name)")
                    }
                }
                .listStyle(.bordered)
                .environment(\.defaultMinListRowHeight, Metrics.Row.list)
                .accessibilityIdentifier("customCommands.list")
                HStack(spacing: Metrics.Spacing.xs) {
                    Button { viewModel.add() } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add Command")
                        .accessibilityIdentifier("customCommands.add")
                    Button { if let id = viewModel.selectedID { viewModel.remove(id) } } label: { Image(systemName: "minus") }
                        .disabled(viewModel.selectedID == nil)
                        .accessibilityLabel("Remove Command")
                        .accessibilityIdentifier("customCommands.remove")
                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(Metrics.Spacing.xs)
            }
            .frame(width: Metrics.Sheet.commandListWidth)
            .padding(Metrics.Spacing.l)
            if let command = viewModel.selected {
                CustomCommandEditor(command: command, viewModel: viewModel)
                    .id(command.id)
            } else {
                EmptyStateView("No Custom Commands", systemImage: "command", message: "Add a git or shell command with + to run it from menus and Quick Launch.")
                    .accessibilityIdentifier("customCommands.empty")
            }
        }
        .frame(minHeight: Metrics.Panel.minimumContentHeight)
    }
}

private struct CustomCommandEditor: View {
    let command: CustomCommand
    let viewModel: CustomCommandsSettingsViewModel

    var body: some View {
        Form {
            TextField("Name", text: binding(\.name), prompt: Text("Open Pull Request"))
                .accessibilityIdentifier("customCommands.name")
            Picker("Run as", selection: binding(\.kind)) {
                ForEach(CustomCommandKind.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("customCommands.kind")
            VStack(alignment: .leading, spacing: Metrics.Spacing.xs) {
                Text("Command")
                    .font(Metrics.Font.title)
                    .foregroundStyle(Palette.Text.primary.color)
                DialogTextEditor(placeholder: "", text: binding(\.commandLine), height: Metrics.Sheet.commandEditorHeight, identifier: "customCommands.commandLine", isMonospaced: true)
                caption(command.kind == .git
                    ? "Runs git with these arguments (a leading git is optional) and shows it in the Git Console with its output and a lesson."
                    : "Runs with /bin/sh -c in the repository root; the output shows in the Git Console.")
                caption("Variables: " + CustomCommandVariable.allCases.map { "\($0.token) \($0.explanation)" }.joined(separator: "; ") + ". Values are quoted for you, so a branch or file name can never run as code.")
            }
            Section("Show in") {
                ForEach(CustomCommandLocation.allCases) { location in
                    Toggle(location.title, isOn: Binding(
                        get: { command.locations.contains(location) },
                        set: { viewModel.setLocation(location, enabled: $0, for: command.id) }
                    ))
                    .accessibilityIdentifier("customCommands.location.\(location.rawValue)")
                }
            }
            Toggle("Ask before running", isOn: binding(\.confirmsBeforeRunning))
                .accessibilityIdentifier("customCommands.confirm")
            if let problem = command.problem {
                Label(problem.localizedDescription, systemImage: "exclamationmark.triangle")
                    .font(Metrics.Font.caption)
                    .foregroundStyle(Palette.Status.conflict.ink.color)
                    .accessibilityIdentifier("customCommands.problem")
            }
        }
        .formStyle(.grouped)
    }

    private func binding<Value: Equatable>(_ keyPath: WritableKeyPath<CustomCommand, Value>) -> Binding<Value> {
        let id = command.id
        return Binding(
            get: { viewModel.commands.first { $0.id == id }?[keyPath: keyPath] ?? command[keyPath: keyPath] },
            set: { value in viewModel.update(id) { $0[keyPath: keyPath] = value } }
        )
    }

    private func caption(_ text: String) -> some View {
        SettingCaption(text: text)
    }
}
