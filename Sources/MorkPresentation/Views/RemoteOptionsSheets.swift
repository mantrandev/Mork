import MorkDomain
import SwiftUI

struct RemoteDialog<Fields: View>: View {
    let title: String
    let subtitle: String?
    let glyph: String
    let kind: DialogKind
    let confirmTitle: String
    let identifier: String
    let canConfirm: Bool
    let isDestructive: Bool
    let command: String?
    let commandIdentifier: String?
    let warning: String?
    let warningIdentifier: String?
    let onConfirm: () -> Void
    let fields: Fields
    @Environment(\.dismiss) private var dismiss

    init(
        title: String,
        subtitle: String? = nil,
        glyph: String,
        kind: DialogKind = .options,
        confirmTitle: String,
        identifier: String,
        canConfirm: Bool,
        isDestructive: Bool = false,
        command: String? = nil,
        commandIdentifier: String? = nil,
        warning: String? = nil,
        warningIdentifier: String? = nil,
        onConfirm: @escaping () -> Void,
        @ViewBuilder fields: () -> Fields
    ) {
        self.title = title
        self.subtitle = subtitle
        self.glyph = glyph
        self.kind = kind
        self.confirmTitle = confirmTitle
        self.identifier = identifier
        self.canConfirm = canConfirm
        self.isDestructive = isDestructive
        self.command = command
        self.commandIdentifier = commandIdentifier
        self.warning = warning
        self.warningIdentifier = warningIdentifier
        self.onConfirm = onConfirm
        self.fields = fields()
    }

    var body: some View {
        DialogScaffold(kind: kind, glyph: glyph, title: title, message: subtitle) {
            VStack(alignment: .leading, spacing: Metrics.Sheet.rowSpacing) {
                fields
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let command {
                CommandStrip(command: command, identifier: commandIdentifier)
            }
        } leading: {
            if let warning {
                DialogNote(text: warning, tone: .warning)
                    .optionalIdentifier(warningIdentifier)
            }
        } buttons: {
            DialogCancelButton { dismiss() }
            DialogConfirmButton(title: confirmTitle, isDestructive: isDestructive, identifier: "\(identifier).confirm") {
                onConfirm()
                dismiss()
            }
            .disabled(!canConfirm)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}

enum NoRemoteNote {
    static let text = "This repository has no remote. Add one first."
    static let command = PushForm.addRemoteHint
}

private enum RemoteLabel {
    static let systemImage = "network"
}

private struct BranchLabel: View {
    static let systemImage = "arrow.triangle.branch"

    let name: String

    var body: some View {
        Label(name, systemImage: Self.systemImage)
            .font(Metrics.Font.title)
    }
}

struct PullOptionsSheet: View {
    let viewModel: RepositoryViewModel
    @State private var form: PullForm

    init(viewModel: RepositoryViewModel) {
        self.viewModel = viewModel
        _form = State(initialValue: PullForm(
            current: viewModel.currentBranch,
            remotes: viewModel.remotes.map(\.name),
            remoteBranches: viewModel.remoteBranches,
            rebase: viewModel.lastPullMode == .rebase,
            autostash: viewModel.lastPullAutostash
        ))
    }

    var body: some View {
        RemoteDialog(
            title: "Pull",
            subtitle: "Fetch the remote branch, then merge or rebase it into the current branch.",
            glyph: "arrow.down",
            confirmTitle: "Pull",
            identifier: "pullSheet",
            canConfirm: form.options != nil,
            command: form.options.map { DialogCommands.line($0.arguments) } ?? NoRemoteNote.command,
            commandIdentifier: "pullSheet.command",
            warning: form.remotes.isEmpty ? NoRemoteNote.text : nil,
            warningIdentifier: "pullSheet.noRemote",
            onConfirm: confirm
        ) {
            PullFields(form: $form)
        }
    }

    private func confirm() {
        guard let options = form.options else { return }
        Task { await viewModel.pull(options: options) }
    }
}

private struct PullFields: View {
    @Binding var form: PullForm

    var body: some View {
        DialogLabeledRow("Remote") {
            BranchPopUp(items: form.remotes.map { BranchPopUp.Item(title: $0, tag: $0, systemImage: RemoteLabel.systemImage) }, selection: Binding(get: { form.remote }, set: { form.select(remote: $0) }), identifier: "pullSheet.remote")
        }
        DialogLabeledRow("Branch") {
            BranchPopUp(items: form.branches.map { BranchPopUp.Item(title: $0, tag: $0, systemImage: BranchLabel.systemImage) }, selection: $form.branchName, identifier: "pullSheet.branch")
        }
        DialogLabeledRow("Into") {
            BranchLabel(name: form.into ?? "detached HEAD")
                .font(Metrics.Font.title)
                .foregroundStyle(Palette.Text.primary.color)
                .accessibilityIdentifier("pullSheet.into")
        }
        DialogLabeledRow("Options") {
            VStack(alignment: .leading, spacing: Metrics.Spacing.s) {
                DialogOptionToggle(title: "Rebase instead of merge", isOn: $form.rebase)
                    .accessibilityIdentifier("pullSheet.rebase")
                DialogOptionToggle(title: "Stash and reapply local changes", isOn: $form.autostash)
                    .accessibilityIdentifier("pullSheet.autostash")
            }
        }
    }
}

struct PushOptionsSheet: View {
    let viewModel: RepositoryViewModel
    @State private var form: PushForm

    init(viewModel: RepositoryViewModel, branchName: String? = nil) {
        self.viewModel = viewModel
        _form = State(initialValue: PushForm(branches: viewModel.branches, remotes: viewModel.remotes.map(\.name), selecting: branchName))
    }

    var body: some View {
        RemoteDialog(
            title: "Push",
            subtitle: "Upload the commits of a local branch to its remote branch.",
            glyph: "arrow.up",
            confirmTitle: "Push",
            identifier: "pushSheet",
            canConfirm: form.canPush,
            command: form.command,
            commandIdentifier: "pushSheet.command",
            warning: warning,
            warningIdentifier: form.remotes.isEmpty ? "pushSheet.noRemote" : "pushSheet.forceWarning",
            onConfirm: confirm
        ) {
            PushFields(form: $form)
        }
    }

    private var warning: String? {
        if form.remotes.isEmpty { return NoRemoteNote.text }
        return form.forceWithLease ? "Rewrites \(form.remote)/\(form.branchName)" : nil
    }

    private func confirm() {
        guard let branch = form.branch, form.canPush else { return }
        Task { await viewModel.push(branch, to: form.remote, includeTags: form.includeTags, forceWithLease: form.forceWithLease) }
    }
}

private struct PushFields: View {
    @Binding var form: PushForm

    var body: some View {
        DialogLabeledRow("Branch") {
            BranchPopUp(items: form.branches.map { BranchPopUp.Item(title: $0.name, tag: $0.name, systemImage: BranchLabel.systemImage) }, selection: $form.branchName, identifier: "pushSheet.branch")
        }
        DialogLabeledRow("To") {
            BranchPopUp(items: form.remotes.map { BranchPopUp.Item(title: form.destinationTitle(for: $0), tag: $0, systemImage: BranchLabel.systemImage) }, selection: $form.remote, identifier: "pushSheet.remote")
        }
        DialogLabeledRow("Options") {
            VStack(alignment: .leading, spacing: Metrics.Spacing.s) {
                ShortcutOption(shortcut: "⌃⌘T") {
                    DialogOptionToggle(title: "Push all tags", isOn: $form.includeTags)
                        .keyboardShortcut("t", modifiers: [.command, .control])
                        .accessibilityIdentifier("pushSheet.tags")
                }
                ShortcutOption(shortcut: "⌃⌘P") {
                    DialogOptionToggle(title: "Force push", isOn: $form.forceWithLease)
                        .keyboardShortcut("p", modifiers: [.command, .control])
                        .accessibilityIdentifier("pushSheet.forceWithLease")
                }
            }
        }
    }
}

private struct ShortcutOption<Content: View>: View {
    let shortcut: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.Spacing.s) {
            content
            Spacer(minLength: 0)
            Text(shortcut)
                .font(Metrics.Font.caption)
                .foregroundStyle(Palette.Text.secondary.color)
                .accessibilityHidden(true)
        }
    }
}

struct FetchOptionsSheet: View {
    let viewModel: RepositoryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var form: FetchForm?

    init(viewModel: RepositoryViewModel) {
        self.viewModel = viewModel
        _form = State(initialValue: FetchForm(remotes: viewModel.remotes.map(\.name)))
    }

    var body: some View {
        DialogScaffold(
            kind: .options,
            glyph: "arrow.down.circle",
            title: "Fetch",
            message: "Download new commits and branches from a remote without changing your files."
        ) {
            if let form = Binding($form) {
                FetchFormFields(form: form)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        } leading: {
            if form?.remotes.isEmpty == true {
                DialogNote(text: NoRemoteNote.text, tone: .warning)
                    .accessibilityIdentifier("fetchSheet.noRemote")
            }
        } buttons: {
            DialogCancelButton { dismiss() }
            DialogConfirmButton(title: "Fetch", identifier: "fetchSheet.confirm", action: confirm)
                .disabled(form?.canFetch != true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fetchSheet")
    }

    private func confirm() {
        guard let form, let options = form.options, form.canFetch else { return }
        dismiss()
        Task { await viewModel.fetch(options: options) }
    }
}

private struct FetchFormFields: View {
    @Binding var form: FetchForm

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Sheet.rowSpacing) {
            DialogLabeledRow("Remote") {
                Picker("Remote", selection: $form.remote) {
                    Text("All Remotes (--all)").tag(String?.none)
                    ForEach(form.remotes, id: \.self) { Text($0).tag(String?.some($0)) }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("fetchSheet.remote")
            }
            DialogLabeledRow("Refspec") {
                DialogTextField(placeholder: "Refspec (optional)", text: $form.refspec, prompt: "main or +refs/heads/*:refs/remotes/origin/*", identifier: "fetchSheet.refspec", isMonospaced: true)
                    .disabled(!form.acceptsRefspec)
                    .help(form.acceptsRefspec ? "Which remote branches to download and where to store them" : "Choose one remote to fetch a refspec")
            }
            if let problem = form.problem {
                DialogLabeledRow(nil) {
                    DialogNote(text: problem, tone: .danger)
                        .accessibilityIdentifier("fetchSheet.problem")
                }
            }
            DialogLabeledRow("Options") {
                VStack(alignment: .leading, spacing: Metrics.Spacing.s) {
                    DialogOptionToggle(title: "Prune deleted remote branches (--prune)", isOn: $form.prune)
                        .accessibilityIdentifier("fetchSheet.prune")
                    DialogOptionToggle(title: "Fetch all tags (--tags)", isOn: $form.tags)
                        .accessibilityIdentifier("fetchSheet.tags")
                }
            }
        }
        CommandStrip(command: form.command, identifier: "fetchSheet.command")
            .id(form.command)
    }
}
