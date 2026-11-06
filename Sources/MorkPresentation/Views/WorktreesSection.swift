import AppKit
import MorkDomain
import SwiftUI

struct WorktreesSection: View {
    let viewModel: RepositoryViewModel
    @Binding var isExpanded: Bool
    @Binding var sheet: WorkspaceSheet?

    var body: some View {
        Group {
            SidebarSectionHeader(title: "Worktrees", isExpanded: $isExpanded, addHelp: "Add Worktree…", identifier: "sidebar.addWorktree") { sheet = .addWorktree }
                .background(InkSelectionTableStyle())
                .contextMenu {
                    Button("New Worktree…") { sheet = .addWorktree }
                        .accessibilityIdentifier("worktreesMenu.newWorktree")
                }
                .sidebarSectionHeaderRow()
            if isExpanded {
                ForEach(viewModel.worktreeRows) { row in
                    WorktreeRowView(row: row, viewModel: viewModel)
                        .sidebarRowInsets()
                }
            }
        }
    }

}

struct WorktreeMenu: View {
    let row: WorktreeRow
    let viewModel: RepositoryViewModel
    @Binding var sheet: WorkspaceSheet?
    @Binding var confirmation: WorkspaceConfirmation?
    let onOpenRepository: (URL) -> Void

    var body: some View {
        let worktree = row.worktree
        Button("Open") { Task { await viewModel.activateSidebar(.worktree(worktree.path), openRepository: onOpenRepository) } }
            .disabled(row.isCurrent || worktree.isPrunable)
            .accessibilityIdentifier("worktreeMenu.open")
        Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([viewModel.url(of: worktree)]) }
            .disabled(worktree.isPrunable)
            .accessibilityIdentifier("worktreeMenu.reveal")
        Button("Copy Path") { Pasteboard.copy(worktree.path) }
        Divider()
        if worktree.isLocked {
            Button("Unlock") { Task { await viewModel.unlockWorktree(worktree) } }
                .accessibilityIdentifier("worktreeMenu.unlock")
        } else {
            Button("Lock…") { sheet = .lockWorktree(worktree) }
                .disabled(worktree.isMain)
                .accessibilityIdentifier("worktreeMenu.lock")
        }
        Button("Remove…", role: .destructive) { confirmation = .removeWorktree(worktree) }
            .disabled(worktree.isMain || row.isCurrent || worktree.isLocked)
            .accessibilityIdentifier("worktreeMenu.remove")
        Divider()
        Button("Prune Missing Worktrees") { Task { await viewModel.pruneWorktrees() } }
            .accessibilityIdentifier("worktreeMenu.prune")
        Button("Add Worktree…") { sheet = .addWorktree }
    }
}

private struct WorktreeRowView: View {
    let row: WorktreeRow
    let viewModel: RepositoryViewModel

    private var worktree: Worktree { row.worktree }

    var body: some View {
        SidebarRow(
            systemImage: row.isCurrent ? "checkmark" : "folder",
            tint: row.isCurrent ? Palette.Accent.text.color : Palette.Text.secondary.color,
            iconWeight: row.isCurrent ? .bold : .regular
        ) {
            Text(worktree.name)
                .fontWeight(row.isCurrent ? .semibold : .regular)
        } trailing: {
            SidebarCaption(text: caption, truncation: .middle)
            if worktree.isLocked {
                Image(systemName: "lock.fill")
                    .font(Metrics.Font.caption)
                    .foregroundStyle(Palette.Text.secondary.color)
                    .accessibilityLabel("locked")
            }
            if worktree.isPrunable {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(Metrics.Font.caption)
                    .foregroundStyle(Palette.Status.conflict.ink.color)
                    .accessibilityLabel("prunable")
            }
        }
        .help(help)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("worktree.\(worktree.name)")
        .accessibilityValue(flags)
        .sidebarSelectable(.worktree(worktree.path), viewModel: viewModel)
    }

    private var caption: String {
        if worktree.isBare { return "bare" }
        if let branch = worktree.branch { return branch }
        return "detached at \(worktree.shortHead ?? "?")"
    }

    private var flags: String {
        [row.isCurrent ? "current" : nil, worktree.isLocked ? "locked" : nil, worktree.isPrunable ? "prunable" : nil, worktree.isDetached ? "detached" : nil]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    private var help: String {
        var lines = [worktree.path]
        if row.isCurrent { lines.append("This window shows this worktree.") }
        if let reason = worktree.lockReason { lines.append(reason.isEmpty ? "Locked" : "Locked: \(reason)") }
        if let reason = worktree.prunableReason { lines.append("Folder is missing (\(reason)). Prune or Remove cleans it up.") }
        if worktree.isDetached { lines.append("Detached HEAD: no branch is checked out here.") }
        return lines.joined(separator: "\n")
    }
}

struct AddWorktreeSheet: View {
    @State var form: WorktreeForm
    var pickFolder: () -> URL? = { FolderPicker.pick(prompt: "Choose") }
    let onAdd: (AddWorktreeRequest) -> Void

    var body: some View {
        RemoteDialog(
            title: "Add Worktree",
            glyph: "square.on.square.dashed",
            kind: .form,
            confirmTitle: "Add Worktree",
            identifier: "worktreeSheet",
            canConfirm: form.canAdd,
            command: DialogCommands.addWorktree(form),
            commandIdentifier: "worktreeSheet.command",
            onConfirm: add
        ) {
            DialogLabeledRow(nil) {
                Picker("Branch", selection: $form.mode) {
                    ForEach(WorktreeForm.Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .accessibilityIdentifier("worktreeSheet.mode")
            }
            switch form.mode {
            case .newBranch:
                DialogLabeledRow("Branch") {
                    DialogTextField(placeholder: "feature/name", text: $form.branchName, identifier: "worktreeSheet.branch")
                }
                DialogLabeledRow("Start at") {
                    DialogTextField(placeholder: "HEAD", text: $form.startPoint, identifier: "worktreeSheet.startPoint")
                }
            case .existingBranch:
                DialogLabeledRow("Branch") {
                    BranchPopUp(items: form.availableBranches.map { BranchPopUp.Item(title: $0, tag: $0) }, selection: $form.existingBranch, identifier: "worktreeSheet.existingBranch")
                }
            }
            DialogLabeledRow("Folder") {
                HStack(spacing: Metrics.Spacing.s) {
                    DialogTextField(placeholder: "/path/to/folder", text: $form.path, identifier: "worktreeSheet.path", isMonospaced: true)
                    Button("Choose…") {
                        if let url = pickFolder() { form.path = url.path }
                    }
                    .buttonStyle(.morkSecondary)
                    .accessibilityIdentifier("worktreeSheet.choose")
                }
            }
            if form.mode == .existingBranch, form.availableBranches.isEmpty {
                DialogLabeledRow(nil) {
                    DialogNote(text: "Every local branch is already checked out in a worktree. A branch can be checked out in only one worktree.", tone: .warning)
                }
            }
        }
    }

    private func add() {
        guard let request = form.request else { return }
        onAdd(request)
    }
}

struct LockWorktreeSheet: View {
    let worktree: Worktree
    let onLock: (String) -> Void
    @State private var reason = ""

    var body: some View {
        RemoteDialog(
            title: "Lock Worktree \(worktree.name)",
            glyph: "lock",
            kind: .form,
            confirmTitle: "Lock",
            identifier: "lockSheet",
            canConfirm: true,
            command: DialogCommands.lockWorktree(worktree.path, reason: reason),
            onConfirm: { onLock(reason) }
        ) {
            DialogLabeledRow("Reason") {
                DialogTextField(placeholder: "optional", text: $reason, identifier: "lockSheet.reason")
            }
        }
    }
}
