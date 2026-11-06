import AppKit
import MorkDomain
import SwiftUI

enum WorkspaceSheet: Identifiable {
    case addRemote
    case editRemote(Remote)
    case addWorktree
    case lockWorktree(Worktree)
    case addSubmodule
    case updateSubmodules
    case checkoutWorktree(Branch)
    case push(Branch)
    case newBranch(from: Branch)
    case newTag(at: Branch)
    case renameBranch(Branch)
    case interactiveRebase(InteractiveRebaseViewModel)
    case tagAction(TagActionPrompt)

    var id: String {
        switch self {
        case .addRemote: "addRemote"
        case let .editRemote(remote): "editRemote.\(remote.name)"
        case .addWorktree: "addWorktree"
        case let .lockWorktree(worktree): "lockWorktree.\(worktree.path)"
        case .addSubmodule: "addSubmodule"
        case .updateSubmodules: "updateSubmodules"
        case let .checkoutWorktree(branch): "checkoutWorktree.\(branch.fullName)"
        case let .push(branch): "push.\(branch.fullName)"
        case let .newBranch(branch): "newBranch.\(branch.fullName)"
        case let .newTag(branch): "newTag.\(branch.fullName)"
        case let .renameBranch(branch): "renameBranch.\(branch.fullName)"
        case let .interactiveRebase(session): "interactiveRebase.\(session.id)"
        case let .tagAction(prompt): "tagAction.\(prompt.id)"
        }
    }
}

enum WorkspaceConfirmation: Identifiable {
    case removeRemote(Remote)
    case deleteRemoteBranch(Branch)
    case removeWorktree(Worktree)
    case forceRemoveWorktree(Worktree)

    var id: String { title }

    var title: String {
        switch self {
        case let .removeRemote(remote): "Remove remote \(remote.name)?"
        case let .deleteRemoteBranch(branch): "Delete \(branch.localName) on \(branch.remoteName ?? "the remote")?"
        case let .removeWorktree(worktree): "Remove worktree \(worktree.name)?"
        case let .forceRemoveWorktree(worktree): "\(worktree.name) has uncommitted changes"
        }
    }

    var confirmTitle: String {
        switch self {
        case .removeRemote: "Remove Remote"
        case .deleteRemoteBranch: "Delete Remote Branch"
        case .removeWorktree: "Remove Worktree"
        case .forceRemoveWorktree: "Force Remove (--force)"
        }
    }

    var identifier: String {
        switch self {
        case .removeRemote: "confirm.removeRemote"
        case .deleteRemoteBranch: "confirm.deleteRemoteBranch"
        case .removeWorktree: "confirm.removeWorktree"
        case .forceRemoveWorktree: "confirm.forceRemoveWorktree"
        }
    }
}

struct WorkspacePrompts: ViewModifier {
    let viewModel: RepositoryViewModel
    @Binding var sheet: WorkspaceSheet?
    @Binding var confirmation: WorkspaceConfirmation?
    let onOpenRepository: (URL) -> Void

    func body(content: Content) -> some View {
        content
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .addRemote:
                    RemoteSheet(form: RemoteForm(existingNames: viewModel.remotes.map(\.name))) { form in
                        Task { await viewModel.addRemote(name: form.name, url: form.url, fetch: form.fetchAfterAdd) }
                    }
                case let .editRemote(remote):
                    RemoteSheet(form: RemoteForm(editing: remote, existingNames: viewModel.remotes.map(\.name))) { form in
                        Task { await viewModel.editRemote(remote, edit: form.edit) }
                    }
                case .addWorktree:
                    AddWorktreeSheet(form: viewModel.makeWorktreeForm()) { request in
                        Task { await viewModel.addWorktree(path: request.path, checkout: request.checkout) }
                    }
                case let .lockWorktree(worktree):
                    LockWorktreeSheet(worktree: worktree) { reason in
                        Task { await viewModel.lockWorktree(worktree, reason: reason) }
                    }
                case .addSubmodule:
                    AddSubmoduleSheet { form in
                        Task { await viewModel.addSubmodule(url: form.url, path: form.path) }
                    }
                case .updateSubmodules:
                    SubmoduleUpdateSheet(viewModel: viewModel)
                case let .checkoutWorktree(branch):
                    AddWorktreeSheet(form: viewModel.makeWorktreeForm(checkingOut: branch)) { request in
                        Task {
                            guard await viewModel.addWorktree(path: request.path, checkout: request.checkout) else { return }
                            onOpenRepository(URL(fileURLWithPath: request.path))
                        }
                    }
                case let .push(branch):
                    PushOptionsSheet(viewModel: viewModel, branchName: branch.name)
                case let .newBranch(branch):
                    BranchAtCommitSheet(title: "New Branch from '\(branch.name)'", startPoint: branch.name, identifier: "branchFromSheet", branchNames: viewModel.localBranches.map(\.name)) { name, checkout in
                        Task { await viewModel.createBranch(named: name, from: branch, checkout: checkout) }
                    }
                case let .newTag(branch):
                    CreateTagSheet(viewModel: viewModel, target: .branch(branch), identifier: "tagAtBranchSheet")
                case let .renameBranch(branch):
                    RenameBranchSheet(form: viewModel.makeRenameForm(for: branch)) { form in
                        Task { await viewModel.rename(form) }
                    }
                case let .interactiveRebase(session):
                    InteractiveRebaseSheet(session: session)
                case let .tagAction(prompt):
                    TagActionSheet(prompt: prompt, viewModel: viewModel)
                }
            }
            .morkConfirmation(item: $confirmation) { confirmation in
                MorkConfirmation(
                    kind: .destructive,
                    glyph: glyph(for: confirmation),
                    title: confirmation.title,
                    message: message(for: confirmation),
                    commands: [command(for: confirmation)],
                    actions: [DialogAction(title: confirmation.confirmTitle, isDestructive: true, identifier: confirmation.identifier) { confirm(confirmation) }],
                    cancelIdentifier: "confirm.cancel"
                )
            }
    }

    private func glyph(for confirmation: WorkspaceConfirmation) -> String {
        switch confirmation {
        case .removeRemote: "network.slash"
        case .deleteRemoteBranch: "icloud.slash"
        case .removeWorktree, .forceRemoveWorktree: "folder.badge.minus"
        }
    }

    private func command(for confirmation: WorkspaceConfirmation) -> DialogCommandLine {
        switch confirmation {
        case let .removeRemote(remote): DialogCommands.removeRemote(remote.name)
        case let .deleteRemoteBranch(branch): DialogCommands.deleteRemoteBranch(remote: branch.remoteName ?? "", branch: branch.localName)
        case let .removeWorktree(worktree): DialogCommands.removeWorktree(worktree.path, force: false)
        case let .forceRemoveWorktree(worktree): DialogCommands.removeWorktree(worktree.path, force: true)
        }
    }

    private func message(for confirmation: WorkspaceConfirmation) -> String {
        switch confirmation {
        case let .removeRemote(remote):
            viewModel.removalMessage(for: remote)
        case let .deleteRemoteBranch(branch):
            "The branch is deleted on \(branch.remoteName ?? "the server") for everyone. Commits that only this branch had are gone there unless someone pushes them again."
        case let .removeWorktree(worktree):
            "The folder is deleted. The branch \(worktree.branch ?? "") and its commits stay in the repository, so you can add the worktree again."
        case .forceRemoveWorktree:
            "The folder has uncommitted or untracked changes. Removing it with --force deletes them for good; commit or stash them first to keep them."
        }
    }

    private func confirm(_ confirmation: WorkspaceConfirmation) {
        switch confirmation {
        case let .removeRemote(remote):
            Task { await viewModel.removeRemote(remote) }
        case let .deleteRemoteBranch(branch):
            Task { await viewModel.deleteRemoteBranch(branch) }
        case let .removeWorktree(worktree):
            Task {
                if await viewModel.removeWorktree(worktree, force: false) == .needsForce {
                    self.confirmation = .forceRemoveWorktree(worktree)
                }
            }
        case let .forceRemoveWorktree(worktree):
            Task { _ = await viewModel.removeWorktree(worktree, force: true) }
        }
    }
}

extension View {
    func workspacePrompts(viewModel: RepositoryViewModel, sheet: Binding<WorkspaceSheet?>, confirmation: Binding<WorkspaceConfirmation?>, onOpenRepository: @escaping (URL) -> Void) -> some View {
        modifier(WorkspacePrompts(viewModel: viewModel, sheet: sheet, confirmation: confirmation, onOpenRepository: onOpenRepository))
    }
}

struct SidebarSectionHeader: View {
    let title: String
    @Binding var isExpanded: Bool
    var addHelp: String? = nil
    let identifier: String
    var add: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: Metrics.Spacing.xxs) {
            Image(systemName: "chevron.right")
                .font(.system(size: Metrics.Icon.disclosure, weight: .bold))
                .foregroundStyle(Palette.Text.secondary.color)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .frame(width: Metrics.Indent.disclosure)
            Text(title)
                .font(Metrics.Font.body.weight(.semibold))
                .foregroundStyle(Palette.Text.primary.color)
            Spacer(minLength: Metrics.Spacing.xs)
            if let add, let addHelp {
                Button(action: add) {
                    Image(systemName: "plus")
                        .font(.system(size: Metrics.Icon.small, weight: .semibold))
                        .frame(width: Metrics.HitTarget.icon, height: Metrics.HitTarget.icon)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.Text.secondary.color)
                .help(addHelp)
            }
        }
        .frame(height: Metrics.Row.sidebar)
        .contentShape(Rectangle())
        .onTapGesture { isExpanded.toggle() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isExpanded ? "expanded" : "collapsed")
        .accessibilityAddTraits(.isHeader)
        .accessibilityAction(named: isExpanded ? "Collapse" : "Expand") { isExpanded.toggle() }
        .modifier(AddAction(help: addHelp, add: add))
        .accessibilityIdentifier(identifier)
    }
}

private struct AddAction: ViewModifier {
    let help: String?
    let add: (() -> Void)?

    func body(content: Content) -> some View {
        if let help, let add {
            content.accessibilityAction(named: help, add)
        } else {
            content
        }
    }
}

enum Pasteboard {
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

struct SidebarPlaceholder: View {
    let text: String
    let identifier: String

    var body: some View {
        Text(text)
            .font(Metrics.Font.caption)
            .foregroundStyle(Palette.Text.secondary.color)
            .padding(.leading, SidebarRow<Text, EmptyView>.titleInset + Metrics.Spacing.xxs)
            .frame(height: SidebarView.rowHeight)
            .accessibilityIdentifier(identifier)
            .sidebarRowInsets()
    }
}
