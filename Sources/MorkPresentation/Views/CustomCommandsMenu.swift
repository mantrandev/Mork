import MorkDomain
import SwiftUI

struct CustomCommandsMenu: View {
    let viewModel: RepositoryViewModel
    let location: CustomCommandLocation
    var branch: Branch?
    var commit: Commit?
    var file: String?

    var body: some View {
        let commands = viewModel.customCommands(for: location)
        if !commands.isEmpty {
            Divider()
            Menu("Custom Commands") {
                ForEach(commands) { command in
                    Button(command.confirmsBeforeRunning ? "\(command.name)…" : command.name) {
                        Task { await viewModel.run(command, branch: branch, commit: commit, file: file) }
                    }
                    .accessibilityIdentifier("customCommand.\(command.name)")
                }
            }
            .accessibilityIdentifier("customCommands.\(location.rawValue)")
        }
    }
}

extension View {
    func customCommandConfirmation(_ viewModel: RepositoryViewModel) -> some View {
        modifier(CustomCommandConfirmation(viewModel: viewModel))
    }
}

private struct CustomCommandConfirmation: ViewModifier {
    @Bindable var viewModel: RepositoryViewModel

    func body(content: Content) -> some View {
        content.morkConfirmation(item: Binding(get: { viewModel.pendingCustomCommand }, set: { viewModel.pendingCustomCommand = $0 })) { pending in
            MorkConfirmation(
                kind: .form,
                glyph: "terminal",
                title: "Run \(pending.command.name)?",
                commands: [DialogCommandLine(text: pending.commandLine)],
                actions: [DialogAction(title: "Run", isDefault: true, identifier: "customCommand.confirm") { Task { await viewModel.confirmPendingCustomCommand() } }]
            )
        }
    }
}
