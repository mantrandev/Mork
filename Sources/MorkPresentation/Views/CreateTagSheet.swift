import MorkDomain
import SwiftUI

struct CreateTagSheet: View {
    let viewModel: RepositoryViewModel
    let target: TagTarget
    let identifier: String
    @AppStorage("tag.pushToAllRemotes") private var pushToAllRemotes = true
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var message = ""

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isAnnotated: Bool { !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var hasRemotes: Bool { !viewModel.remotes.isEmpty }
    private var pushes: Bool { hasRemotes && pushToAllRemotes }

    var body: some View {
        RemoteDialog(
            title: "Create Tag",
            glyph: "tag",
            kind: .form,
            confirmTitle: pushes ? "Create and Push" : "Create",
            identifier: identifier,
            canConfirm: !trimmedName.isEmpty,
            onConfirm: create
        ) {
            DialogLabeledRow("Tag at") {
                Label(targetTitle, systemImage: targetIcon)
                    .font(Metrics.Font.title)
                    .foregroundStyle(Palette.Text.primary.color)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityIdentifier("\(identifier).target")
            }
            DialogLabeledRow("Name") {
                DialogTextField(placeholder: "v1.0.0", text: $name, identifier: "\(identifier).name") {
                    guard !trimmedName.isEmpty else { return }
                    create()
                    dismiss()
                }
            }
            DialogLabeledRow("Message") {
                DialogTextEditor(placeholder: "optional", text: $message, height: Metrics.TagSheet.messageHeight, identifier: "\(identifier).message")
            }
            DialogLabeledRow(nil) {
                DialogOptionToggle(title: "Push to all remotes", isOn: $pushToAllRemotes)
                    .disabled(!hasRemotes)
                    .help(hasRemotes ? "git push <remote> refs/tags/<name> for every remote" : "This repository has no remotes")
                    .accessibilityIdentifier("\(identifier).push")
            }
            VStack(alignment: .leading, spacing: Metrics.Spacing.xs) {
                ForEach(Array(commands.enumerated()), id: \.offset) { _, command in
                    CommandStrip(command: command.text, note: command.note)
                }
            }
        }
    }

    private var commands: [DialogCommandLine] {
        let tagName = trimmedName.isEmpty ? "<name>" : trimmedName
        let create = DialogCommandLine(text: DialogCommands.createTag(name: tagName, message: message, revision: revision))
        let push = pushes ? DialogCommands.pushTag(tagName, to: viewModel.remotes.map(\.name)) : nil
        return [create] + (push.map { [$0] } ?? [])
    }

    private var revision: String? {
        switch target {
        case .head: nil
        case let .branch(branch): branch.name
        case let .commit(commit): commit.hash
        }
    }

    private var targetTitle: String {
        switch target {
        case .head: viewModel.currentBranch?.name ?? "HEAD"
        case let .branch(branch): branch.name
        case let .commit(commit): "\(commit.shortHash) \(commit.subject)"
        }
    }

    private var targetIcon: String {
        switch target {
        case .head, .branch: "arrow.triangle.branch"
        case .commit: "smallcircle.filled.circle"
        }
    }

    private func create() {
        let name = trimmedName
        let message = message
        let push = pushes
        let target = target
        Task { await viewModel.createTag(named: name, message: message, at: target, pushToRemotes: push) }
    }
}
