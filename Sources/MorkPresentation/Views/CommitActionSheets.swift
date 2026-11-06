import MorkDomain
import SwiftUI

struct CheckoutCommitSheet: View {
    let commit: Commit
    let branch: Branch?
    let checkoutCommit: () -> Void
    let checkoutBranch: (Branch) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        DialogScaffold(
            kind: .form,
            glyph: "smallcircle.filled.circle",
            title: "Checkout Commit \(commit.shortHash)?",
            message: "New commits here belong to no branch (detached HEAD).",
            width: branch == nil ? nil : Metrics.Sheet.dialogWidth
        ) {
            CommitSummaryRow(commit: commit)
            CommitCommandStrip(arguments: ["switch", "--detach", commit.shortHash], note: branch == nil ? DialogCommandLine.confirmNote : "Checkout Detached", identifier: "checkoutCommitSheet.command")
            if let branch {
                DialogNote(text: "'\(branch.name)' points at this commit. Checking out the branch keeps you on it, so new commits move it forward.")
                CommitCommandStrip(arguments: ["switch", branch.name], note: "Checkout Branch", identifier: "checkoutCommitSheet.branchCommand")
            }
        } buttons: {
            DialogCancelButton { dismiss() }
            if let branch {
                Button("Checkout Detached") { confirm(checkoutCommit) }
                    .buttonStyle(.morkSecondary)
                    .accessibilityIdentifier("checkoutCommitSheet.confirm")
                DialogConfirmButton(title: "Checkout Branch", identifier: "checkoutCommitSheet.branch") { confirm { checkoutBranch(branch) } }
            } else {
                DialogConfirmButton(title: "Checkout", identifier: "checkoutCommitSheet.confirm") { confirm(checkoutCommit) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("checkoutCommitSheet")
    }

    private func confirm(_ action: () -> Void) {
        action()
        dismiss()
    }
}

struct CherryPickCommitSheet: View {
    let commit: Commit
    let branchName: String
    let onConfirm: (CherryPickOptions) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var commitsResult = true
    @State private var recordsOrigin = false

    private var options: CherryPickOptions { CherryPickOptions(commitsResult: commitsResult, recordsOrigin: recordsOrigin) }

    var body: some View {
        DialogScaffold(
            kind: .form,
            glyph: "arrow.uturn.right",
            title: "Cherry-pick \(commit.shortHash) onto '\(branchName)'?"
        ) {
            CommitSummaryRow(commit: commit)
            DialogLabeledRow("Options") {
                VStack(alignment: .leading, spacing: Metrics.Spacing.s) {
                    DialogOptionToggle(title: "Commit the result", isOn: $commitsResult)
                        .accessibilityIdentifier("cherryPickSheet.commit")
                    DialogOptionToggle(title: "Append 'cherry picked from' line", isOn: $recordsOrigin)
                        .disabled(!commitsResult)
                        .accessibilityIdentifier("cherryPickSheet.appendOrigin")
                }
            }
            if commit.isMerge {
                DialogNote(text: "This is a merge commit. -m 1 copies what it brought in compared with its first parent, the branch it was merged into.")
            }
            CommitCommandStrip(arguments: options.arguments(revision: commit.shortHash, mainline: commit.mainline), identifier: "cherryPickSheet.command")
        } buttons: {
            DialogCancelButton { dismiss() }
            DialogConfirmButton(title: "Cherry-pick", identifier: "cherryPickSheet.confirm") {
                onConfirm(options)
                dismiss()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cherryPickSheet")
    }
}

struct RevertCommitSheet: View {
    let commit: Commit
    let onConfirm: (RevertOptions) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var commitsResult = true

    private var options: RevertOptions { RevertOptions(commitsResult: commitsResult) }

    var body: some View {
        DialogScaffold(
            kind: .form,
            glyph: "arrow.uturn.backward",
            title: "Revert \(commit.shortHash)?"
        ) {
            CommitSummaryRow(commit: commit)
            DialogLabeledRow("Options") {
                DialogOptionToggle(title: "Commit the result", isOn: $commitsResult)
                    .accessibilityIdentifier("revertSheet.commit")
            }
            if commit.isMerge {
                DialogNote(text: "This is a merge commit. -m 1 undoes what the merge brought in and keeps its first parent, the branch it was merged into.")
            }
            CommitCommandStrip(arguments: options.arguments(revision: commit.shortHash, mainline: commit.mainline), identifier: "revertSheet.command")
        } buttons: {
            DialogCancelButton { dismiss() }
            DialogConfirmButton(title: "Revert", identifier: "revertSheet.confirm") {
                onConfirm(options)
                dismiss()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("revertSheet")
    }
}

private struct CommitSummaryRow: View {
    let commit: Commit

    var body: some View {
        DialogLabeledRow("Commit") {
            HStack(alignment: .firstTextBaseline, spacing: Metrics.Spacing.s) {
                Text(commit.shortHash)
                    .font(Metrics.Font.monoCaption)
                    .foregroundStyle(Palette.Accent.text.color)
                Text(commit.subject)
                    .font(Metrics.Font.title)
                    .foregroundStyle(Palette.Text.primary.color)
                    .lineLimit(2)
            }
        }
    }
}

private struct CommitCommandStrip: View {
    let arguments: [String]
    var note: String? = DialogCommandLine.confirmNote
    let identifier: String

    var body: some View {
        CommandStrip(command: DialogCommands.line(arguments), note: note, identifier: identifier)
            .help(Lessons.explain(arguments) ?? "")
    }
}
