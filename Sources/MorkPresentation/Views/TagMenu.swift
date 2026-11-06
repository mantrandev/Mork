import MorkDomain
import SwiftUI

struct TagMenu: View {
    let tag: Tag
    let viewModel: RepositoryViewModel
    @Binding var sheet: WorkspaceSheet?

    var body: some View {
        Button("Checkout Commit…") { withCommit { sheet = .tagAction(.checkout($0)) } }
            .accessibilityIdentifier("tagMenu.checkout")
        Button("Show Tag Details…") { sheet = .tagAction(.details(tag)) }
            .accessibilityIdentifier("tagMenu.details")
        Divider()
        if let remote = viewModel.tagPushRemote {
            Button("Push to '\(remote)'…") { sheet = .tagAction(.push(tag, remote: remote)) }
                .accessibilityIdentifier("tagMenu.push")
        }
        Divider()
        Button("Merge into '\(viewModel.currentBranch?.name ?? "HEAD")'…") { sheet = .tagAction(.merge(tag)) }
            .disabled(viewModel.hasRevisionOperation)
            .accessibilityIdentifier("tagMenu.merge")
        Button("Rebase on '\(tag.name)'…") { sheet = .tagAction(.rebase(tag)) }
            .disabled(viewModel.currentBranch == nil || viewModel.hasRevisionOperation)
            .accessibilityIdentifier("tagMenu.rebase")
        Button("Interactively Rebase on '\(tag.name)'…") {
            withCommit { commit in
                Task { if let session = await viewModel.makeInteractiveRebase(onto: commit) { sheet = .interactiveRebase(session) } }
            }
        }
        .disabled(viewModel.currentBranch == nil || viewModel.hasRevisionOperation)
        .accessibilityIdentifier("tagMenu.interactiveRebase")
        Divider()
        Button("New Branch…") { withCommit { sheet = .tagAction(.newBranch($0)) } }
            .keyboardShortcut("b", modifiers: [.command, .shift])
            .accessibilityIdentifier("tagMenu.newBranch")
        Button("New Tag…") { withCommit { sheet = .tagAction(.newTag($0)) } }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .accessibilityIdentifier("tagMenu.newTag")
        Divider()
        Button("Delete…", role: .destructive) { sheet = .tagAction(.delete(tag)) }
            .keyboardShortcut(.delete, modifiers: [])
            .accessibilityIdentifier("tagMenu.delete")
        Divider()
        Button("Copy Tag Name") { Pasteboard.copy(tag.name) }
            .keyboardShortcut("c")
            .accessibilityIdentifier("tagMenu.copyName")
    }

    private func withCommit(_ action: @escaping @MainActor (Commit) -> Void) {
        Task { if let commit = await viewModel.tagCommit(tag) { action(commit) } }
    }
}

enum TagActionPrompt: Identifiable {
    case delete(Tag)
    case checkout(Commit)
    case details(Tag)
    case push(Tag, remote: String)
    case merge(Tag)
    case rebase(Tag)
    case newBranch(Commit)
    case newTag(Commit)

    var id: String {
        switch self {
        case let .delete(tag): "delete.\(tag.name)"
        case let .checkout(commit): "checkout.\(commit.hash)"
        case let .details(tag): "details.\(tag.name)"
        case let .push(tag, remote): "push.\(remote).\(tag.name)"
        case let .merge(tag): "merge.\(tag.name)"
        case let .rebase(tag): "rebase.\(tag.name)"
        case let .newBranch(commit): "branch.\(commit.hash)"
        case let .newTag(commit): "tag.\(commit.hash)"
        }
    }
}

struct TagActionSheet: View {
    let prompt: TagActionPrompt
    let viewModel: RepositoryViewModel

    var body: some View {
        switch prompt {
        case let .delete(tag):
            DeleteTagSheet(tag: tag, viewModel: viewModel)
        case let .checkout(commit):
            CheckoutCommitSheet(commit: commit, branch: nil) {
                Task { await viewModel.checkout(commit) }
            } checkoutBranch: { _ in }
        case let .details(tag):
            TagDetailsSheet(tag: tag, viewModel: viewModel)
        case let .newBranch(commit):
            BranchAtCommitSheet(commit: commit, branchNames: viewModel.localBranches.map(\.name)) { name, checkout in
                Task { await viewModel.createBranch(named: name, at: commit, checkout: checkout) }
            }
        case let .newTag(commit):
            CreateTagSheet(viewModel: viewModel, target: .commit(commit), identifier: "tagFromTagSheet")
        case let .push(tag, remote):
            RemoteDialog(title: "Push Tag", glyph: "arrow.up", confirmTitle: "Push", identifier: "pushTagSheet", canConfirm: !viewModel.isBusy && viewModel.remotes.contains { $0.name == remote }, command: DialogCommands.line(["push", remote, tag.reference])) {
                Task { await viewModel.push(tag, to: remote) }
            } fields: {
                EmptyView()
            }
        case let .merge(tag):
            RemoteDialog(title: "Merge Tag", glyph: "arrow.triangle.merge", confirmTitle: "Merge", identifier: "mergeTagSheet", canConfirm: !viewModel.isBusy && !viewModel.hasRevisionOperation, command: DialogCommands.line(["merge", "--no-edit", tag.reference])) {
                Task { await viewModel.merge(tag) }
            } fields: {
                EmptyView()
            }
        case let .rebase(tag):
            RemoteDialog(title: "Rebase on Tag", glyph: "arrow.triangle.pull", confirmTitle: "Rebase", identifier: "rebaseTagSheet", canConfirm: !viewModel.isBusy && viewModel.currentBranch != nil && !viewModel.hasRevisionOperation, command: DialogCommands.line(["rebase"] + (viewModel.hasUncommittedChanges ? ["--autostash"] : []) + [tag.reference])) {
                Task { await viewModel.rebase(onto: tag) }
            } fields: {
                EmptyView()
            }
        }
    }
}

private struct TagDetailsSheet: View {
    let tag: Tag
    let viewModel: RepositoryViewModel
    @State private var details: Loadable<String> = .idle
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        DialogScaffold(kind: .notice, glyph: "tag", title: "Tag '\(tag.name)'", message: "What git stores about the tag and its commit.", width: Metrics.Sheet.wideWidth) {
            CommandStrip(command: DialogCommands.line(["show", "--no-patch", "--format=fuller", tag.reference, "--"]))
            ScrollView {
                switch details {
                case .idle, .loading: ProgressView()
                case let .loaded(text): Text(text).font(Metrics.Font.monoBody).foregroundStyle(Palette.Text.primary.color).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                case let .failed(message): DialogNote(text: message, tone: .danger)
                }
            }
            .padding(Metrics.Spacing.s)
            .frame(minHeight: Metrics.Sheet.scrollMinimumHeight)
            .background(Palette.Surface.well.color, in: RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous))
        } buttons: {
            DialogCancelButton(title: "Close") { dismiss() }
        }
        .accessibilityIdentifier("tagDetailsSheet")
        .task {
            details = .loading
            do { details = .loaded(try await viewModel.tagDetails(tag)) }
            catch { details = .failed(error.localizedDescription) }
        }
    }
}
