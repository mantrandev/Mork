import MorkDomain
import SwiftUI

struct RemotesSection: View {
    let viewModel: RepositoryViewModel
    @Binding var isExpanded: Bool
    @Binding var toggled: Set<String>
    @Binding var sheet: WorkspaceSheet?
    @Binding var confirmation: WorkspaceConfirmation?

    var body: some View {
        Group {
            SidebarSectionHeader(title: "Remotes", isExpanded: $isExpanded, addHelp: "Add Remote…", identifier: "sidebar.addRemote") { sheet = .addRemote }
                .contextMenu { RemotesSectionMenu(viewModel: viewModel, sheet: $sheet) }
                .sidebarSectionHeaderRow()
            if isExpanded {
                RemoteRows(viewModel: viewModel, toggled: $toggled, sheet: $sheet, confirmation: $confirmation)
            }
        }
    }
}

struct RemotesSectionMenu: View {
    let viewModel: RepositoryViewModel
    @Binding var sheet: WorkspaceSheet?

    var body: some View {
        Button("Add New Remote…") { sheet = .addRemote }
            .accessibilityIdentifier("remotesMenu.addRemote")
        Divider()
        Text("Sort Branches:")
        ForEach(BranchSortOrder.allCases, id: \.self) { order in
            Toggle(order == .recentlyUsed ? "Recently used (deprecated)" : order.title, isOn: Binding(
                get: { viewModel.remoteBranchSortOrder == order },
                set: { if $0 { Task { await viewModel.setRemoteBranchSortOrder(order) } } }
            ))
            .accessibilityIdentifier("remotesMenu.sort.\(order.rawValue)")
        }
    }
}

private struct RemoteRows: View {
    let viewModel: RepositoryViewModel
    @Binding var toggled: Set<String>
    @Binding var sheet: WorkspaceSheet?
    @Binding var confirmation: WorkspaceConfirmation?

    var body: some View {
        let isFiltering = viewModel.isFilteringBranches
        let collapsed = BranchOutline.collapsed(toggled: toggled, tree: viewModel.remoteBranchTree, collapsesByDefault: viewModel.prefersCollapsedBranchFolders)
        Group {
            if viewModel.remoteSections.isEmpty, !isFiltering {
                SidebarPlaceholder(text: "No remotes. Click + to add one.", identifier: "sidebar.noRemotes")
            }
            ForEach(viewModel.remoteSections) { section in
                let folderID = BranchOutline.folderPrefix + section.name
                let isExpanded = isFiltering || !collapsed.contains(folderID)
                RemoteRow(section: section, isExpanded: isExpanded) {
                    toggled.formSymmetricDifference([folderID])
                }
                .contextMenu { remoteMenu(section.remote) }
                .sidebarRowInsets()
                if isExpanded {
                    ForEach(BranchOutline.rows(section.nodes, collapsed: collapsed, expandAll: isFiltering)) { row in
                        RemoteBranchOutlineRow(
                            row: row,
                            viewModel: viewModel,
                            isExpanded: isFiltering || !collapsed.contains(row.id),
                            toggle: { toggled.formSymmetricDifference([row.id]) }
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func remoteMenu(_ remote: Remote?) -> some View {
        if let remote {
            Button("Fetch \(remote.name)") { Task { await viewModel.fetchRemote(remote) } }
                .accessibilityIdentifier("remoteMenu.fetch")
            Button("Prune Stale Branches") { Task { await viewModel.pruneRemote(remote) } }
                .accessibilityIdentifier("remoteMenu.prune")
            Divider()
            Button("Copy URL") { Pasteboard.copy(remote.fetchURL) }
                .accessibilityIdentifier("remoteMenu.copyURL")
            Button("Edit Remote…") { sheet = .editRemote(remote) }
                .accessibilityIdentifier("remoteMenu.edit")
            Divider()
            Button("Remove Remote…", role: .destructive) { confirmation = .removeRemote(remote) }
                .accessibilityIdentifier("remoteMenu.remove")
        }
        Button("Add Remote…") { sheet = .addRemote }
    }
}

private struct RemoteBranchOutlineRow: View {
    let row: BranchOutline.Row
    let viewModel: RepositoryViewModel
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        let nested = BranchOutline.Row(node: row.node, depth: row.depth + 1)
        if let branch = row.node.branch {
            BranchRow(branch: branch, title: row.node.name, depth: nested.depth, selection: .remoteBranch(branch.name), viewModel: viewModel)
                .sidebarRowInsets()
        } else {
            FolderRow(row: nested, systemImage: "folder", isExpanded: isExpanded, identifier: "remoteFolder", toggle: toggle)
                .sidebarRowInsets()
        }
    }
}

struct RemoteBranchMenu: View {
    let branch: Branch
    let viewModel: RepositoryViewModel
    @Binding var sheet: WorkspaceSheet?
    @Binding var confirmation: WorkspaceConfirmation?

    var body: some View {
        Button("Checkout as Local Branch") { Task { await viewModel.checkout(branch) } }
            .accessibilityIdentifier("remoteBranchMenu.checkout")
        Button("Checkout as Worktree…") { sheet = .checkoutWorktree(branch) }
            .disabled(!viewModel.canCheckoutAsWorktree(branch))
            .accessibilityIdentifier("remoteBranchMenu.checkoutWorktree")
        Divider()
        Button("Merge into '\(viewModel.currentBranch?.name ?? "HEAD")'") { Task { await viewModel.merge(branch) } }
            .accessibilityIdentifier("remoteBranchMenu.merge")
        Button(viewModel.rebaseMenuTitle(onto: branch)) { Task { await viewModel.rebase(onto: branch, autostash: viewModel.hasUncommittedChanges) } }
            .disabled(viewModel.isDetachedHead)
            .accessibilityIdentifier("remoteBranchMenu.rebase")
        InteractiveRebaseButton(branch: branch, viewModel: viewModel, sheet: $sheet, identifier: "remoteBranchMenu.interactiveRebase")
        Divider()
        NewBranchAndTagButtons(branch: branch, sheet: $sheet, identifierPrefix: "remoteBranchMenu")
        Divider()
        Button(viewModel.setUpstreamTitle(for: branch)) { Task { await viewModel.setUpstream(branch) } }
            .disabled(viewModel.isDetachedHead || viewModel.isUpstreamOfCurrentBranch(branch))
            .accessibilityIdentifier("remoteBranchMenu.setUpstream")
        CopyBranchNameButton(branch: branch, identifier: "remoteBranchMenu.copyName")
        Divider()
        BranchVisibilityMenu(branch: branch, viewModel: viewModel)
        Divider()
        Button("Delete \(branch.localName) on \(branch.remoteName ?? "Remote")…", role: .destructive) { confirmation = .deleteRemoteBranch(branch) }
            .accessibilityIdentifier("remoteBranchMenu.delete")
    }
}

private struct RemoteRow: View {
    let section: RemoteSection
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        SidebarRow(systemImage: "network", disclosure: section.nodes.isEmpty ? nil : isExpanded) {
            Text(section.name)
        } trailing: {
            if let remote = section.remote {
                SidebarCaption(text: Self.caption(for: remote.fetchURL), truncation: .head)
            } else {
                SidebarCaption(text: "no longer configured", tint: Palette.Status.conflict.ink.color)
            }
        }
        .sidebarItemChrome()
        .onTapGesture(perform: toggle)
        .help(help)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { toggle() }
        .accessibilityIdentifier("remote.\(section.name)")
        .accessibilityValue(section.remote?.fetchURL ?? "")
    }

    private var help: String {
        guard let remote = section.remote else { return "Remote-tracking branches of a remote that is not in .git/config anymore" }
        var lines = ["fetch: \(remote.fetchURL)"]
        lines.append("push: \(remote.effectivePushURL)")
        return lines.joined(separator: "\n")
    }

    static func caption(for url: String) -> String {
        var trimmed = url
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        guard let slash = trimmed.lastIndex(where: { $0 == "/" || $0 == ":" }) else { return trimmed }
        return String(trimmed[trimmed.index(after: slash)...])
    }
}
