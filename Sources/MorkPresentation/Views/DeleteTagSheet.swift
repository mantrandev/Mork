import MorkDomain
import SwiftUI

struct DeleteTagSheet: View {
    let tag: Tag
    let viewModel: RepositoryViewModel
    @State private var chosenRemotes: Set<String> = []

    var body: some View {
        RemoteDialog(
            title: "Delete Tag '\(tag.name)'",
            subtitle: "The commit stays in history, so you can tag it again. Tags deleted on a remote are gone there for everyone.",
            glyph: "trash",
            kind: .destructive,
            confirmTitle: "Delete Tag",
            identifier: "deleteTagSheet",
            canConfirm: !viewModel.isBusy,
            isDestructive: true
        ) {
            let remotes = viewModel.remotes.map(\.name).filter(chosenRemotes.contains)
            Task { await viewModel.delete(tag, fromRemotes: remotes) }
        } fields: {
            DialogLabeledRow("Tag") {
                Label {
                    Text(tag.name).foregroundStyle(Palette.Text.primary.color)
                } icon: {
                    Image(systemName: "tag").foregroundStyle(Palette.Status.conflict.ink.color)
                }
                .font(Metrics.Font.title)
                .accessibilityIdentifier("deleteTagSheet.tag")
            }
            if viewModel.remotes.isEmpty {
                DialogLabeledRow(nil) {
                    DialogOptionToggle(title: "Delete tag from remote repositories", isOn: .constant(false))
                        .disabled(true)
                        .help("This repository has no remotes")
                        .accessibilityIdentifier("deleteTagSheet.remotes")
                }
            } else {
                ForEach(viewModel.remotes, id: \.name) { remote in
                    DialogLabeledRow(nil) {
                        DialogOptionToggle(title: "Delete tag from '\(remote.name)'", isOn: chosen(remote.name))
                            .accessibilityIdentifier("deleteTagSheet.remote.\(remote.name)")
                    }
                }
            }
            VStack(alignment: .leading, spacing: Metrics.Spacing.xs) {
                if let remote = DialogCommands.deleteRemoteTag(tag.name, from: viewModel.remotes.map(\.name).filter(chosenRemotes.contains)) {
                    CommandStrip(command: remote.text, note: remote.note)
                }
                CommandStrip(command: DialogCommands.deleteTags([tag.name]).text, note: DialogCommandLine.confirmNote)
            }
        }
    }

    private func chosen(_ remote: String) -> Binding<Bool> {
        Binding {
            chosenRemotes.contains(remote)
        } set: { isOn in
            if isOn { chosenRemotes.insert(remote) } else { chosenRemotes.remove(remote) }
        }
    }
}
