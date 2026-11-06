import MorkDomain
import SwiftUI

enum BranchBatchPrompt: Identifiable {
    case push([Branch], String)
    case delete([Branch])

    var id: String {
        switch self {
        case .push: "push"
        case .delete: "delete"
        }
    }
}

struct BranchBatchMenu: View {
    let branches: [Branch]
    let viewModel: RepositoryViewModel
    @Binding var prompt: BranchBatchPrompt?

    var body: some View {
        Button("Fast-Forward \(branches.count) Branches to Their Upstreams") {
            Task { await viewModel.fastForward(branches) }
        }
        .disabled(!branches.allSatisfy(\.canFastForward))
        .accessibilityIdentifier("branchBatch.fastForward")
        if let remote = viewModel.batchPushRemote(for: branches) {
            Button("Push \(branches.count) Branches to '\(remote)'…") { prompt = .push(branches, remote) }
                .accessibilityIdentifier("branchBatch.push")
        }
        Divider()
        Button("Delete \(branches.count) Branches…", role: .destructive) { prompt = .delete(branches) }
            .disabled(branches.contains(where: \.isCurrent))
            .accessibilityIdentifier("branchBatch.delete")
        Divider()
        Button("Copy Branch Names") { Pasteboard.copy(branches.map(\.name).joined(separator: "\n")) }
            .accessibilityIdentifier("branchBatch.copyNames")
    }
}

struct BranchBatchSheet: View {
    let prompt: BranchBatchPrompt
    let viewModel: RepositoryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var alsoDeleteRemote = false
    @State private var pendingServerDeletion: Bool?
    @State private var remote = ""

    var body: some View {
        switch prompt {
        case let .push(branches, initialRemote):
            DialogScaffold(
                kind: .options,
                glyph: "arrow.up",
                title: "Push \(branches.count) Branches"
            ) {
                branchNames(branches)
                DialogLabeledRow("Remote") {
                    Picker("Remote", selection: $remote) {
                        ForEach(viewModel.remotes) { remote in Text(remote.name).tag(remote.name) }
                    }
                    .labelsHidden()
                }
                if let first = branches.first, !remote.isEmpty {
                    CommandStrip(command: DialogCommands.line(PushOptions(branch: first, remote: remote, includeTags: false, forceWithLease: false).arguments), note: branches.count > 1 ? "runs for \(branches.count) branches" : DialogCommandLine.confirmNote)
                }
            } buttons: {
                DialogCancelButton { dismiss() }
                DialogConfirmButton(title: "Push", identifier: "branchBatchSheet.push") {
                    let target = remote
                    Task { await viewModel.push(branches, to: target) }
                    dismiss()
                }
                .disabled(!viewModel.remotes.contains { $0.name == remote })
            }
            .onAppear { remote = initialRemote }
        case let .delete(branches):
            let targets = Array(Set(branches.compactMap { viewModel.remoteBranchForDeletion(of: $0)?.name })).sorted()
            if let force = pendingServerDeletion, !targets.isEmpty {
                serverConfirmation(branches, targets: targets, force: force)
            } else {
                deleteChoice(branches, targets: targets)
            }
        }
    }

    private func deleteChoice(_ branches: [Branch], targets: [String]) -> some View {
        DialogScaffold(
            kind: .destructive,
            title: "Delete \(branches.count) Branches?",
            message: "Only the names go away. Commits that are on no other branch can still be found in the reflog, so you can recreate the branches from them.",
            width: DeleteBranchButtons.dialogWidth
        ) {
            branchNames(branches)
            if !targets.isEmpty {
                DialogOptionToggle(title: "Also delete \(targets.count) tracked remote branches", isOn: $alsoDeleteRemote)
                    .accessibilityIdentifier("branchBatchSheet.alsoDeleteRemote")
            }
            if let first = branches.first {
                CommandStrip(command: DialogCommands.line(["branch", "-d", first.name]), note: branches.count > 1 ? "runs for \(branches.count) branches" : "-D to force")
            }
        } buttons: {
            DeleteBranchButtons(identifier: "branchBatchSheet", cancel: { dismiss() }, choose: { choose(branches, targets: targets, force: $0) })
        }
    }

    private func serverConfirmation(_ branches: [Branch], targets: [String], force: Bool) -> some View {
        DialogScaffold(
            kind: .destructive,
            glyph: "icloud.slash",
            title: "Delete \(targets.count) branches on the server?",
            message: "Everyone who uses these remotes loses the branches. Mork cannot undo this; push the branches again to bring them back."
        ) {
            Text(targets.joined(separator: "\n"))
                .font(Metrics.Font.monoBody)
                .foregroundStyle(Palette.Text.primary.color)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Metrics.Spacing.s)
                .padding(.horizontal, Metrics.Sheet.commandStripInset)
                .background(Palette.Surface.well.color, in: RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous))
                .accessibilityIdentifier("branchBatchSheet.serverTargets")
        } buttons: {
            DialogCancelButton(title: "Back", identifier: "branchBatchSheet.back") { pendingServerDeletion = nil }
            DialogConfirmButton(title: "Delete on Server", isDestructive: true, isDefault: false, identifier: "branchBatchSheet.confirmServer") { delete(branches, force: force) }
        }
    }

    private func choose(_ branches: [Branch], targets: [String], force: Bool) {
        if alsoDeleteRemote, !targets.isEmpty {
            pendingServerDeletion = force
        } else {
            delete(branches, force: force)
        }
    }

    private func branchNames(_ branches: [Branch]) -> some View {
        ScrollView {
            Text(branches.map(\.name).joined(separator: "\n"))
                .font(Metrics.Font.title)
                .foregroundStyle(Palette.Text.primary.color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .frame(height: min(CGFloat(branches.count) * Metrics.LineHeight.title, Metrics.Sheet.batchNamesHeight))
    }

    private func delete(_ branches: [Branch], force: Bool) {
        let includeRemote = alsoDeleteRemote
        Task { await viewModel.delete(branches, force: force, alsoDeleteRemote: includeRemote) }
        dismiss()
    }
}
