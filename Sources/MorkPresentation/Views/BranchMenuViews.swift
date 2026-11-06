import AppKit
import MorkDomain
import SwiftUI

struct DeleteBranchButtons: View {
    static let dialogWidth = Metrics.Sheet.dialogWidth

    let identifier: String
    let cancel: () -> Void
    let choose: (Bool) -> Void

    var body: some View {
        DialogCancelButton(action: cancel)
        Button("Force Delete (-D)") { choose(true) }
            .buttonStyle(.morkDestructive)
            .accessibilityIdentifier("\(identifier).forceDelete")
        DialogConfirmButton(title: "Delete (only if merged)", identifier: "\(identifier).delete") { choose(false) }
    }
}

struct DeleteBranchSheet: View {
    let branch: Branch
    let remoteBranch: Branch?
    let onDelete: (Bool, Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var alsoDeleteRemote = false
    @State private var pendingServerDeletion: Bool?

    var body: some View {
        if let remoteBranch, let force = pendingServerDeletion {
            serverConfirmation(remoteBranch, force: force)
        } else {
            choice
        }
    }

    private var choice: some View {
        DialogScaffold(
            kind: .destructive,
            title: "Delete branch '\(branch.name)'?",
            message: "Only the name goes away. Commits that are on no other branch can still be found in the reflog, so you can recreate the branch from them.",
            width: DeleteBranchButtons.dialogWidth
        ) {
            if let remoteBranch {
                VStack(alignment: .leading, spacing: Metrics.Spacing.xs) {
                    DialogOptionToggle(title: "Also delete '\(remoteBranch.name)'", isOn: $alsoDeleteRemote)
                        .accessibilityIdentifier("deleteBranchSheet.alsoDeleteRemote")
                }
            }
            CommandStrip(command: DialogCommands.line(["branch", "-d", branch.name]), note: "-D to force")
        } buttons: {
            DeleteBranchButtons(identifier: "deleteBranchSheet", cancel: { dismiss() }, choose: choose(force:))
        }
    }

    private func serverConfirmation(_ remoteBranch: Branch, force: Bool) -> some View {
        DialogScaffold(
            kind: .destructive,
            glyph: "icloud.slash",
            title: "Delete '\(remoteBranch.name)' on the server?",
            message: "Everyone who uses this remote loses the branch. Mork cannot undo this; push the branch again to bring it back."
        ) {
            CommandStrip(command: DialogCommands.deleteRemoteBranch(remote: remoteBranch.remoteName ?? "", branch: remoteBranch.localName).text, note: DialogCommandLine.confirmNote, identifier: "deleteBranchSheet.serverCommand")
        } buttons: {
            DialogCancelButton(title: "Back", identifier: "deleteBranchSheet.back") { pendingServerDeletion = nil }
            DialogConfirmButton(title: "Delete on Server", isDestructive: true, isDefault: false, identifier: "deleteBranchSheet.confirmServer") { finish(force: force) }
        }
    }

    private func choose(force: Bool) {
        if alsoDeleteRemote, remoteBranch != nil {
            pendingServerDeletion = force
        } else {
            finish(force: force)
        }
    }

    private func finish(force: Bool) {
        onDelete(force, alsoDeleteRemote)
        dismiss()
    }
}

struct ForceDeleteBranchSheet: View {
    let deletion: BranchForceDeletion
    let onForceDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        DialogScaffold(
            kind: .warning,
            title: "'\(deletion.branch.name)' is not fully merged",
            message: deletion.reason,
            messageIdentifier: "forceDeleteSheet.reason"
        ) {
            CommandStrip(command: DialogCommands.line(["branch", "-D", deletion.branch.name]), note: DialogCommandLine.confirmNote, identifier: "forceDeleteSheet.command")
        } buttons: {
            DialogCancelButton(identifier: "forceDeleteSheet.cancel") { dismiss() }
            DialogConfirmButton(title: "Force Delete", isDestructive: true, isDefault: false, identifier: "forceDeleteSheet.delete") {
                onForceDelete()
                dismiss()
            }
        }
    }
}

struct TrackingMenu: View {
    let branch: Branch
    let viewModel: RepositoryViewModel

    var body: some View {
        let choices = viewModel.upstreamChoices(for: branch)
        Menu("Tracking") {
            ForEach(choices.matching) { candidate in
                UpstreamChoice(branch: branch, candidate: candidate, viewModel: viewModel)
            }
            if !choices.matching.isEmpty, !choices.groups.isEmpty {
                Divider()
            }
            ForEach(choices.groups) { group in
                Menu(group.remote) {
                    ForEach(group.branches) { candidate in
                        UpstreamChoice(branch: branch, candidate: candidate, viewModel: viewModel)
                    }
                }
                .accessibilityIdentifier("branchMenu.tracking.remote.\(group.remote)")
            }
            if !choices.isEmpty {
                Divider()
            }
            Button("Unset Upstream") { Task { await viewModel.unsetUpstream(branch) } }
                .disabled(branch.upstream == nil)
                .accessibilityIdentifier("branchMenu.unsetUpstream")
        }
        .accessibilityIdentifier("branchMenu.tracking")
    }
}

private struct UpstreamChoice: View {
    let branch: Branch
    let candidate: Branch
    let viewModel: RepositoryViewModel

    var body: some View {
        Toggle(candidate.name, isOn: Binding(get: { branch.upstream == candidate.name }, set: { isOn in
            guard isOn else { return }
            Task { await viewModel.setUpstream(of: branch, to: candidate) }
        }))
        .accessibilityIdentifier("branchMenu.tracking.\(candidate.name)")
    }
}

struct PullRequestButton: View {
    let branch: Branch
    let remote: Remote
    let viewModel: RepositoryViewModel

    var body: some View {
        Button("Create Pull Request on '\(remote.name)'") {
            Task {
                guard let url = await viewModel.pullRequestURL(for: branch) else { return }
                NSWorkspace.shared.open(url)
            }
        }
        .accessibilityIdentifier("branchMenu.pullRequest")
    }
}

struct RenameBranchSheet: View {
    @State var form: RenameBranchForm
    let onRename: (RenameBranchForm) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsRemoteDelete = false

    var body: some View {
        if confirmsRemoteDelete {
            MorkConfirmationView(confirmation: remoteDeleteConfirmation) { confirmsRemoteDelete = false }
        } else {
            renameForm
        }
    }

    private var renameForm: some View {
        DialogScaffold(
            kind: .form,
            glyph: "pencil",
            title: "Rename Branch '\(form.branch.name)'"
        ) {
            VStack(alignment: .leading, spacing: Metrics.Sheet.rowSpacing) {
                DialogLabeledRow("Name") {
                    DialogTextField(placeholder: "feature/name", text: $form.name, identifier: "renameSheet.name", onSubmit: confirm)
                }
                if let problem = form.problem {
                    DialogLabeledRow(nil) {
                        DialogNote(text: problem, tone: .danger)
                            .accessibilityIdentifier("renameSheet.problem")
                    }
                }
                if let remote = form.remote {
                    DialogLabeledRow(nil) {
                        DialogOptionToggle(title: "Also rename on '\(remote)'", isOn: $form.alsoRenameOnRemote)
                            .accessibilityIdentifier("renameSheet.renameOnRemote")
                    }
                }
            }
            VStack(alignment: .leading, spacing: Metrics.Spacing.xs) {
                ForEach(form.commands, id: \.self) { command in
                    CommandStrip(command: command)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(form.commands.joined(separator: "\n"))
            .accessibilityIdentifier("renameSheet.command")
        } buttons: {
            DialogCancelButton { dismiss() }
            DialogConfirmButton(title: "Rename", identifier: "renameSheet.confirm", action: confirm)
                .disabled(!form.canRename)
        }
    }

    private var remoteDeleteConfirmation: MorkConfirmation {
        MorkConfirmation(
            kind: .destructive,
            glyph: "icloud.slash",
            title: "Delete \(form.remote ?? "")/\(form.branch.name) on the server?",
            message: "The new name is pushed first. Anyone who still works on the old name has to switch to the new one.",
            commands: [DialogCommands.deleteRemoteBranch(remote: form.remote ?? "", branch: form.branch.name)],
            actions: [DialogAction(title: "Rename and Delete", isDestructive: true, identifier: "renameSheet.confirmRemoteDelete", perform: finish)]
        )
    }

    private func confirm() {
        guard form.canRename else { return }
        if form.renamesOnRemote {
            confirmsRemoteDelete = true
        } else {
            finish()
        }
    }

    private func finish() {
        onRename(form)
        dismiss()
    }
}
