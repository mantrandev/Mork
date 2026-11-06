import AppKit
import MorkDomain
import SwiftUI

struct SidebarView: View {
    static let rowHeight = Metrics.Row.sidebar

    @Bindable var viewModel: RepositoryViewModel
    var onOpenRepository: (URL) -> Void = { _ in }
    @State private var pendingDeletion: Branch?
    @State private var marks = SidebarSelectionMarks()
    @State private var batchPrompt: BranchBatchPrompt?
    @State private var pendingTagDeletion: [Tag] = []
    @State private var workspaceSheet: WorkspaceSheet?
    @State private var workspaceConfirmation: WorkspaceConfirmation?
    @State private var collapsedLocal: Set<String> = []
    @State private var collapsedRemote: Set<String> = []
    @State private var collapsedSections = SidebarSections.collapsedByDefault
    @Environment(\.sidebarExpandsAllSections) private var expandsAllSections

    var body: some View {
        VStack(spacing: 0) {
            SidebarTop(viewModel: viewModel)
            List(selection: sidebarSelection) {
                WorktreesSection(viewModel: viewModel, isExpanded: expansion("worktrees"), sheet: $workspaceSheet)
                LocalBranchesSection(viewModel: viewModel, isExpanded: expansion("branches"), toggled: $collapsedLocal) {
                    Task { await selectStaleLocalBranches() }
                }
                RemotesSection(viewModel: viewModel, isExpanded: expansion("remotes"), toggled: $collapsedRemote, sheet: $workspaceSheet, confirmation: $workspaceConfirmation)
                TagsSection(viewModel: viewModel, isExpanded: expansion("tags"))
                StashesSection(viewModel: viewModel, isExpanded: expansion("stashes"))
                SubmodulesSection(viewModel: viewModel, isExpanded: expansion("submodules"), sheet: $workspaceSheet)
            }
            .contextMenu(forSelectionType: RepositoryViewModel.SidebarSelection.self) { items in
                if items.count > 1 {
                    let branches = viewModel.localBranches(in: items)
                    let tags = viewModel.tags(in: items)
                    if !branches.isEmpty {
                        BranchBatchMenu(branches: branches, viewModel: viewModel, prompt: $batchPrompt)
                    } else if !tags.isEmpty {
                        Button("Delete \(tags.count) Tags…", role: .destructive) { pendingTagDeletion = tags }
                            .accessibilityIdentifier("tagBatchMenu.delete")
                    }
                } else if let item = items.first {
                    SidebarItemMenu(
                        selection: item,
                        viewModel: viewModel,
                        pendingDeletion: $pendingDeletion,
                        sheet: $workspaceSheet,
                        confirmation: $workspaceConfirmation,
                        onOpenRepository: onOpenRepository
                    )
                }
            } primaryAction: { items in
                guard SidebarPrimaryAction.activates(for: NSApp.currentEvent), items.count == 1, let item = items.first else { return }
                activate(item)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .contentMargins(.top, 0, for: .scrollContent)
            .listItemTint(.monochrome)
            .environment(\.sidebarSelectionMarks, marks)
            .overlayScrollers(hidesFocusRing: true)
            .environment(\.sidebarRowSize, .small)
            .environment(\.defaultMinListRowHeight, Metrics.Row.sidebar)
            .accessibilityIdentifier("sidebar")
        }
        .workspacePrompts(viewModel: viewModel, sheet: $workspaceSheet, confirmation: $workspaceConfirmation, onOpenRepository: onOpenRepository)
        .onAppear {
            if expandsAllSections { collapsedSections = [] }
            marks.onActivate = activate
        }
        .background(CurrentBranchFolderExpander(viewModel: viewModel, toggled: $collapsedLocal))
        .branchDropDialog(viewModel)
        .background(SidebarSelectionSync(viewModel: viewModel, marks: marks))
        .background(SidebarDoubleClickMonitor(marks: marks))
        .morkConfirmation(isPresented: Binding(get: { !pendingTagDeletion.isEmpty }, set: { if !$0 { pendingTagDeletion = [] } })) {
            let tags = pendingTagDeletion
            return MorkConfirmation(
                kind: .destructive,
                title: "Delete \(tags.count) tags?",
                message: tags.map(\.name).joined(separator: ", ") + ". Deletes them on this computer only; tags already pushed stay on the remotes. The commits stay in history, so you can tag them again.",
                commands: [DialogCommands.deleteTags(tags.map(\.name))],
                actions: [DialogAction(title: "Delete", isDestructive: true, identifier: "confirm.deleteTags") { Task { await viewModel.delete(tags: tags) } }]
            )
        }
        .sheet(item: $batchPrompt) { prompt in
            BranchBatchSheet(prompt: prompt, viewModel: viewModel)
        }
        .sheet(item: $pendingDeletion) { branch in
            DeleteBranchSheet(branch: branch, remoteBranch: viewModel.remoteBranchForDeletion(of: branch)) { force, alsoDeleteRemote in
                Task { await viewModel.delete(branch, force: force, alsoDeleteRemote: alsoDeleteRemote) }
            }
        }
        .sheet(item: Binding(get: { viewModel.pendingForceDeletion }, set: { viewModel.pendingForceDeletion = $0 })) { deletion in
            ForceDeleteBranchSheet(deletion: deletion) {
                Task { await viewModel.forceDelete(deletion) }
            }
        }
    }

    private func activate(_ item: RepositoryViewModel.SidebarSelection) {
        Task { await viewModel.activateSidebar(item, openRepository: onOpenRepository) }
    }

    private var sidebarSelection: Binding<Set<RepositoryViewModel.SidebarSelection>> {
        Binding(get: { marks.items.isEmpty ? [viewModel.sidebarSelection] : marks.items }, set: { selection in
            marks.set(selection)
            if selection.count == 1, let item = selection.first { viewModel.selectSidebar(item) }
        })
    }

    private func expansion(_ section: String) -> Binding<Bool> {
        Binding(get: { !collapsedSections.contains(section) }, set: { expanded in
            if expanded { collapsedSections.remove(section) } else { collapsedSections.insert(section) }
        })
    }

    private func selectStaleLocalBranches() async {
        viewModel.branchFilter = ""
        await viewModel.waitForFilters()
        let stale = viewModel.staleLocalBranches
        guard !stale.isEmpty else { return }
        collapsedSections.remove("branches")
        let currentFolders = viewModel.currentBranch.map { BranchOutline.folderIDs(containing: $0.name) } ?? []
        collapsedLocal = viewModel.prefersCollapsedBranchFolders ? BranchOutline.folderIDs(in: viewModel.localBranchTree).subtracting(currentFolders) : []
        marks.set(Set(stale.map { .branch($0.name) }))
        if let only = marks.items.first, marks.items.count == 1 { viewModel.selectSidebar(only) }
    }
}

private struct SidebarTop: View {
    @Bindable var viewModel: RepositoryViewModel

    var body: some View {
        VStack(spacing: 0) {
            RepositoryHeader(viewModel: viewModel)
                .padding(.horizontal, Metrics.Sidebar.listInset)
                .padding(.top, Metrics.Spacing.m)
            ChangesDestination(viewModel: viewModel)
                .padding(.horizontal, Metrics.Sidebar.listInset)
            Destination(viewModel: viewModel, title: "All Commits", systemImage: "tray.full", pane: .history)
                .padding(.horizontal, Metrics.Sidebar.listInset)
            Destination(viewModel: viewModel, title: "Reflog", systemImage: "arrow.uturn.backward.circle", pane: .reflog)
                .padding(.horizontal, Metrics.Sidebar.listInset)
            SidebarModeSwitcher(viewModel: viewModel)
                .padding(.top, Metrics.Spacing.m)
                .padding(.bottom, Metrics.Spacing.xs)
            SearchField(prompt: "Filter", text: $viewModel.branchFilter, identifier: "sidebar.filter")
                .frame(height: Metrics.Sidebar.filterHeight)
                .padding(.horizontal, Metrics.Sidebar.contentInset)
                .padding(.top, Metrics.Spacing.m)
                .padding(.bottom, Metrics.Spacing.s)
        }
    }
}

private struct SidebarModeSwitcher: View {
    let viewModel: RepositoryViewModel

    var body: some View {
        HStack(spacing: Metrics.Sidebar.switcherSpacing) {
            SwitcherIcon(title: "Branches", systemImage: "arrow.triangle.branch", isActive: !viewModel.isSearchActive, identifier: "sidebar.mode.branches") {
                viewModel.clearSearch()
            }
            SwitcherIcon(title: "Search Commits", systemImage: "magnifyingglass", isActive: viewModel.isSearchActive, identifier: "sidebar.mode.search") {
                viewModel.beginSearch()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Metrics.Sidebar.switcherHeight)
        .overlay(alignment: .top) { Hairline() }
        .overlay(alignment: .bottom) { Hairline() }
    }
}

private struct SwitcherIcon: View {
    let title: String
    let systemImage: String
    let isActive: Bool
    let identifier: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: Metrics.Sidebar.destinationIcon, weight: .regular))
                .foregroundStyle(isActive ? Palette.Accent.text.color : Palette.Text.secondary.color)
                .frame(width: Metrics.Sidebar.segmentWidth, height: Metrics.Sidebar.segmentHeight)
                .background(isActive ? Palette.Accent.tint.color : Palette.Text.primary.color.opacity(isHovered ? Palette.Ink.hover : 0), in: RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}

private struct CurrentBranchFolderExpander: View {
    let viewModel: RepositoryViewModel
    @Binding var toggled: Set<String>

    var body: some View {
        Color.clear
            .onChange(of: viewModel.currentBranch?.name, initial: true) { _, name in
                guard let name else { return }
                toggled.subtract(BranchOutline.folderIDs(containing: name))
            }
    }
}

private struct ChangesDestination: View {
    let viewModel: RepositoryViewModel

    var body: some View {
        Destination(viewModel: viewModel, title: "Local Changes", systemImage: "doc.on.doc", pane: .changes, count: viewModel.changes.count)
    }
}

private struct LocalBranchesSection: View {
    let viewModel: RepositoryViewModel
    @Binding var isExpanded: Bool
    @Binding var toggled: Set<String>
    let selectStale: () -> Void

    var body: some View {
        Group {
            SidebarSectionHeader(title: "Branches", isExpanded: $isExpanded, identifier: "sidebar.section.branches")
                .contextMenu { BranchesSectionMenu(viewModel: viewModel, selectStale: selectStale) }
                .sidebarSectionHeaderRow()
            if isExpanded {
                LocalBranchRows(viewModel: viewModel, toggled: $toggled)
            }
        }
    }
}

struct BranchesSectionMenu: View {
    let viewModel: RepositoryViewModel
    let selectStale: () -> Void

    var body: some View {
        Button("New Branch…") { viewModel.sheet = .branch }
            .accessibilityIdentifier("branchesMenu.newBranch")
        Button("Select Stale Local Branches", action: selectStale)
            .disabled(viewModel.staleLocalBranches.isEmpty)
            .help("Select local branches whose upstream is gone, excluding the current branch")
            .accessibilityIdentifier("branchesMenu.selectStale")
        Divider()
        Text("Sort Branches:")
        ForEach(BranchSortOrder.allCases, id: \.self) { order in
            Toggle(order.title, isOn: Binding(
                get: { viewModel.branchSortOrder == order },
                set: { if $0 { Task { await viewModel.setBranchSortOrder(order) } } }
            ))
            .accessibilityIdentifier("branchesMenu.sort.\(order.rawValue)")
        }
    }
}

private struct LocalBranchRows: View {
    let viewModel: RepositoryViewModel
    @Binding var toggled: Set<String>

    var body: some View {
        let isFiltering = viewModel.isFilteringBranches
        let collapsed = BranchOutline.collapsed(
            toggled: toggled,
            tree: viewModel.localBranchTree,
            collapsesByDefault: viewModel.prefersCollapsedBranchFolders,
            keepingOpen: viewModel.currentBranch.map { BranchOutline.folderIDs(containing: $0.name) } ?? []
        )
        if let detached = viewModel.detachedHead {
            DetachedHeadRow(commit: detached)
                .sidebarRowInsets()
        }
        ForEach(BranchOutline.rows(viewModel.localBranchTree, collapsed: collapsed, expandAll: isFiltering)) { row in
            LocalBranchOutlineRow(
                row: row,
                viewModel: viewModel,
                isExpanded: isFiltering || !collapsed.contains(row.id),
                toggle: { toggled.formSymmetricDifference([row.id]) }
            )
        }
    }
}

private struct LocalBranchOutlineRow: View {
    let row: BranchOutline.Row
    let viewModel: RepositoryViewModel
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        if let branch = row.node.branch {
            BranchRow(branch: branch, title: row.node.name, depth: row.depth, selection: .branch(branch.name), viewModel: viewModel)
                .branchDragAndDrop(branch, viewModel: viewModel)
                .sidebarRowInsets()
        } else {
            FolderRow(row: row, systemImage: "folder", isExpanded: isExpanded, identifier: "folder", toggle: toggle)
                .sidebarRowInsets()
        }
    }
}

struct SidebarItemMenu: View {
    let selection: RepositoryViewModel.SidebarSelection
    let viewModel: RepositoryViewModel
    @Binding var pendingDeletion: Branch?
    @Binding var sheet: WorkspaceSheet?
    @Binding var confirmation: WorkspaceConfirmation?
    let onOpenRepository: (URL) -> Void

    var body: some View {
        switch selection {
        case .pane:
            EmptyView()
        case let .branch(name):
            if let branch = viewModel.localBranches.first(where: { $0.name == name }) {
                LocalBranchMenu(branch: branch, viewModel: viewModel, sheet: $sheet) { pendingDeletion = $0 }
                CustomCommandsMenu(viewModel: viewModel, location: .branch, branch: branch)
            }
        case let .remoteBranch(name):
            if let branch = viewModel.remoteBranches.first(where: { $0.name == name }) {
                RemoteBranchMenu(branch: branch, viewModel: viewModel, sheet: $sheet, confirmation: $confirmation)
                CustomCommandsMenu(viewModel: viewModel, location: .branch, branch: branch)
            }
        case let .tag(name):
            if let tag = viewModel.tags.first(where: { $0.name == name }) {
                TagMenu(tag: tag, viewModel: viewModel, sheet: $sheet)
            }
        case let .stash(reference):
            if let stash = viewModel.stashes.first(where: { $0.reference == reference }) {
                Button("Apply") { Task { await viewModel.apply(stash, drop: false) } }
                Button("Pop (apply + drop)") { Task { await viewModel.apply(stash, drop: true) } }
                Divider()
                Button("Drop", role: .destructive) { Task { await viewModel.drop(stash) } }
            }
        case let .worktree(path):
            if let row = viewModel.worktreeRows.first(where: { $0.worktree.path == path }) {
                WorktreeMenu(row: row, viewModel: viewModel, sheet: $sheet, confirmation: $confirmation, onOpenRepository: onOpenRepository)
            }
        case let .submodule(path):
            if let submodule = viewModel.submodules.first(where: { $0.path == path }) {
                SubmoduleMenu(submodule: submodule, viewModel: viewModel, sheet: $sheet, onOpenRepository: onOpenRepository)
            }
        }
    }
}

private struct LocalBranchMenu: View {
    let branch: Branch
    let viewModel: RepositoryViewModel
    @Binding var sheet: WorkspaceSheet?
    let requestDeletion: (Branch) -> Void

    var body: some View {
        Button("Checkout") { Task { await viewModel.checkout(branch) } }
            .disabled(branch.isCurrent)
            .accessibilityIdentifier("branchMenu.checkout")
        Button("Checkout as Worktree…") { sheet = .checkoutWorktree(branch) }
            .disabled(!viewModel.canCheckoutAsWorktree(branch))
            .accessibilityIdentifier("branchMenu.checkoutWorktree")
        Divider()
        if let title = viewModel.fastForwardTitle(for: branch) {
            Button(title) { Task { await viewModel.fastForward(branch) } }
                .disabled(!branch.canFastForward)
                .accessibilityIdentifier("branchMenu.fastForward")
        }
        if let remote = viewModel.pushRemote(for: branch) {
            Button("Push to '\(remote)'…") { sheet = .push(branch) }
                .accessibilityIdentifier("branchMenu.push")
        }
        if let remote = viewModel.pullRequestRemote(for: branch) {
            PullRequestButton(branch: branch, remote: remote, viewModel: viewModel)
        }
        Divider()
        Button("Merge into '\(viewModel.currentBranch?.name ?? "HEAD")'") { Task { await viewModel.merge(branch) } }
            .disabled(branch.isCurrent)
            .accessibilityIdentifier("branchMenu.merge")
        Button(viewModel.rebaseMenuTitle(onto: branch)) { Task { await viewModel.rebase(onto: branch, autostash: viewModel.hasUncommittedChanges) } }
            .disabled(branch.isCurrent || viewModel.isDetachedHead)
            .accessibilityIdentifier("branchMenu.rebase")
        InteractiveRebaseButton(branch: branch, viewModel: viewModel, sheet: $sheet, identifier: "branchMenu.interactiveRebase")
        Divider()
        NewBranchAndTagButtons(branch: branch, sheet: $sheet, identifierPrefix: "branchMenu")
        Divider()
        TrackingMenu(branch: branch, viewModel: viewModel)
        Button("Rename…") { sheet = .renameBranch(branch) }
            .accessibilityIdentifier("branchMenu.rename")
        Button("Delete…", role: .destructive) { requestDeletion(branch) }
            .keyboardShortcut(.delete, modifiers: [])
            .disabled(branch.isCurrent)
            .accessibilityIdentifier("branchMenu.delete")
        Divider()
        CopyBranchNameButton(branch: branch, identifier: "branchMenu.copyName")
        Divider()
        BranchVisibilityMenu(branch: branch, viewModel: viewModel)
    }
}

struct InteractiveRebaseButton: View {
    let branch: Branch
    let viewModel: RepositoryViewModel
    @Binding var sheet: WorkspaceSheet?
    let identifier: String

    var body: some View {
        Button("Interactively Rebase on '\(branch.name)'…") {
            Task {
                guard let session = await viewModel.makeInteractiveRebase(onto: branch) else { return }
                sheet = .interactiveRebase(session)
            }
        }
        .disabled(!viewModel.canInteractivelyRebase(onto: branch))
        .accessibilityIdentifier(identifier)
    }
}

struct NewBranchAndTagButtons: View {
    let branch: Branch
    @Binding var sheet: WorkspaceSheet?
    let identifierPrefix: String

    var body: some View {
        Button("New Branch…") { sheet = .newBranch(from: branch) }
            .keyboardShortcut("b", modifiers: [.command, .shift])
            .accessibilityIdentifier("\(identifierPrefix).newBranch")
        Button("New Tag…") { sheet = .newTag(at: branch) }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .accessibilityIdentifier("\(identifierPrefix).newTag")
    }
}

struct CopyBranchNameButton: View {
    let branch: Branch
    let identifier: String

    var body: some View {
        Button("Copy Branch Name") { Pasteboard.copy(branch.name) }
            .keyboardShortcut("c")
            .accessibilityIdentifier(identifier)
    }
}

struct BranchVisibilityMenu: View {
    let branch: Branch
    let viewModel: RepositoryViewModel

    var body: some View {
        Button(viewModel.isPinned(branch) ? "Unpin" : "Pin to Top") { Task { await viewModel.togglePin(branch) } }
            .accessibilityIdentifier("branchMenu.pin")
        Button(viewModel.isFiltered(to: branch) ? "Remove Branch from History Filter" : "Add Branch to History Filter") { Task { await viewModel.toggleHistoryFilter(branch) } }
            .accessibilityIdentifier("branchMenu.filter")
        Button(viewModel.isHidden(branch) ? "Show in History" : "Hide in History") { Task { await viewModel.toggleHidden(branch) } }
            .accessibilityIdentifier("branchMenu.visibility")
    }
}

private struct TagsSection: View {
    let viewModel: RepositoryViewModel
    @Binding var isExpanded: Bool

    var body: some View {
        Group {
            SidebarSectionHeader(title: "Tags", isExpanded: $isExpanded, identifier: "sidebar.section.tags")
                .contextMenu { TagsSectionMenu(viewModel: viewModel) }
                .sidebarSectionHeaderRow()
            if isExpanded {
                ForEach(viewModel.tagSidebarRows) { row in
                    if let tag = row.tag {
                        TagRow(tag: tag, title: row.title, depth: row.depth, viewModel: viewModel)
                    } else {
                        SidebarRow(systemImage: "folder", depth: row.depth, disclosure: row.isExpanded) {
                            Text(row.title)
                        } trailing: {
                            EmptyView()
                        }
                        .sidebarItemChrome()
                        .onTapGesture { viewModel.toggleTagFolder(row.id) }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { viewModel.toggleTagFolder(row.id) }
                        .accessibilityIdentifier("tagFolder.\(row.id)")
                        .accessibilityValue(row.isExpanded ? "expanded" : "collapsed")
                        .sidebarRowInsets()
                    }
                }
            }
        }
    }
}

struct TagsSectionMenu: View {
    let viewModel: RepositoryViewModel

    var body: some View {
        Button("New Tag…") { viewModel.sheet = .tag }
            .accessibilityIdentifier("tagsMenu.newTag")
        Divider()
        Text("Sort Tags:")
        ForEach(TagSortOrder.allCases, id: \.self) { order in
            Toggle(order.title, isOn: Binding(
                get: { viewModel.tagSortOrder == order },
                set: { if $0 { viewModel.setTagSortOrder(order) } }
            ))
            .accessibilityIdentifier("tagsMenu.sort.\(order.rawValue)")
        }
    }
}

private struct TagRow: View {
    let tag: Tag
    let title: String
    let depth: Int
    let viewModel: RepositoryViewModel

    var body: some View {
        SidebarRow(systemImage: "tag", tint: Palette.Status.conflict.ink.color, depth: depth) {
            Text(title)
        } trailing: {
            if tag.isAnnotated {
                SidebarCaption(text: "annotated")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("tag.\(tag.name)")
        .sidebarSelectable(.tag(tag.name), viewModel: viewModel)
        .sidebarRowInsets()
    }
}

private struct StashesSection: View {
    let viewModel: RepositoryViewModel
    @Binding var isExpanded: Bool

    var body: some View {
        Group {
            SidebarSectionHeader(title: "Stashes", isExpanded: $isExpanded, identifier: "sidebar.section.stashes")
                .contextMenu {
                    Button("Save Stash…") { viewModel.sheet = .stash }
                        .keyboardShortcut("s", modifiers: [.command, .shift])
                        .accessibilityIdentifier("stashesMenu.saveStash")
                }
                .sidebarSectionHeaderRow()
            if isExpanded {
                ForEach(viewModel.stashes) { stash in
                    StashRow(stash: stash)
                        .sidebarSelectable(.stash(stash.reference), viewModel: viewModel)
                        .sidebarRowInsets()
                }
            }
        }
    }
}

extension View {
    func sidebarRowInsets() -> some View {
        listRowInsets(SidebarRow<Text, EmptyView>.insets)
    }

    func sidebarSectionHeaderRow() -> some View {
        selectionDisabled()
            .listRowInsets(EdgeInsets(top: Metrics.Spacing.s, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
    }

    func sidebarSelectable(_ selection: RepositoryViewModel.SidebarSelection, viewModel: RepositoryViewModel) -> some View {
        modifier(SidebarSelectable(selection: selection, viewModel: viewModel))
    }
}

private struct SidebarSelectable: ViewModifier {
    let selection: RepositoryViewModel.SidebarSelection
    let viewModel: RepositoryViewModel

    func body(content: Content) -> some View {
        content
            .accessibilityAddTraits(viewModel.sidebarItem == selection ? .isSelected : [])
            .sidebarItemChrome(selection)
            .tag(selection)
    }
}

enum RepositoryMonogram {
    static func letter(for name: String) -> String {
        name.first { $0.isLetter || $0.isNumber }.map { String($0).uppercased() } ?? ""
    }
}

private struct RepositoryHeader: View {
    let viewModel: RepositoryViewModel
    @State private var anchor = MenuAnchor()

    private var isLinkedWorktree: Bool {
        viewModel.worktreeRows.first(where: \.isCurrent).map { !$0.worktree.isMain } ?? false
    }

    var body: some View {
        HStack(alignment: .center, spacing: Metrics.Spacing.s) {
            RoundedRectangle(cornerRadius: Metrics.Radius.card, style: .continuous)
                .fill(Palette.Accent.tileFill.color)
                .frame(width: Metrics.Sidebar.repositoryTile, height: Metrics.Sidebar.repositoryTile)
                .overlay {
                    Text(RepositoryMonogram.letter(for: viewModel.name))
                        .font(.system(size: Metrics.FontSize.display, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.Accent.tileLabel.color)
                }
                .padding(.trailing, Metrics.Sidebar.repositoryTileGap - Metrics.Spacing.s)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Metrics.Spacing.xxs) {
                Text(viewModel.name)
                    .font(Metrics.Font.heading)
                    .foregroundStyle(Palette.Text.primary.color)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityIdentifier("sidebar.repositoryName")
                HStack(spacing: Metrics.Spacing.xs) {
                    Image(systemName: viewModel.isDetachedHead ? "exclamationmark.triangle.fill" : "arrow.triangle.branch")
                        .font(.system(size: Metrics.Icon.small))
                        .foregroundStyle(viewModel.isDetachedHead ? Palette.Status.conflict.ink.color : Palette.Text.secondary.color)
                    Text(viewModel.headTitle)
                        .font(Metrics.Font.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if isLinkedWorktree {
                        Text("worktree")
                            .font(Metrics.Font.label)
                            .padding(.horizontal, Metrics.Spacing.xs + Metrics.Spacing.xxs)
                            .frame(height: Metrics.Control.badge)
                            .background(Palette.Surface.border.color, in: Capsule())
                    }
                }
                .foregroundStyle(Palette.Text.secondary.color)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("sidebar.repositoryBranch")
            }
            Spacer(minLength: Metrics.Spacing.xs)
            Button(action: showMenu) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: Metrics.Icon.column))
                    .foregroundStyle(Palette.Text.secondary.color)
                    .frame(width: Metrics.HitTarget.icon, height: Metrics.HitTarget.icon)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(MenuAnchorView(anchor: anchor))
            .help("Repository actions")
            .accessibilityLabel("Repository actions")
            .accessibilityIdentifier("sidebar.repositoryMenu")
        }
        .padding(.leading, Metrics.Sidebar.selectionInset)
        .padding(.vertical, Metrics.Spacing.xs + Metrics.Spacing.xxs)
        .help(viewModel.headTitle)
    }

    private func showMenu() {
        anchor.popUp([
            MenuEntry(title: "Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([viewModel.url]) },
            MenuEntry(title: "Open in \(viewModel.editorName ?? "External Editor")", identifier: "sidebar.openInEditor") {
                Task { await viewModel.openRepositoryInEditor() }
            },
            MenuEntry(title: "Open in \(viewModel.terminalAppName)", identifier: "sidebar.openInTerminalApp") {
                Task { await viewModel.openRepositoryInTerminalApp() }
            },
            MenuEntry(title: "Copy Path") { Pasteboard.copy(viewModel.url.path) }
        ])
    }
}

struct SidebarRow<Title: View, Trailing: View>: View {
    static var titleInset: CGFloat { Metrics.Indent.disclosure + Metrics.Spacing.xxs }

    let systemImage: String
    var tint: Color = Palette.Text.secondary.color
    var iconWeight: Font.Weight = .regular
    var depth = 0
    var disclosure: Bool? = nil
    var warning: String? = nil
    @ViewBuilder let title: Title
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 0) {
            DisclosureSlot(isExpanded: disclosure)
            Image(systemName: systemImage)
                .font(.system(size: Metrics.Icon.regular, weight: iconWeight))
                .foregroundStyle(tint)
                .overlay(alignment: .bottomTrailing) {
                    if let warning {
                        WarningBadge()
                            .offset(x: Metrics.Spacing.xs, y: Metrics.Spacing.xxs)
                            .help(warning)
                            .accessibilityLabel(warning)
                    }
                }
                .frame(width: Metrics.Sidebar.iconColumn, alignment: .center)
                .padding(.leading, Metrics.Spacing.xxs)
            title
                .font(Metrics.Font.title)
                .foregroundStyle(Palette.Text.primary.color)
                .lineLimit(1)
                .truncationMode(.middle)
                .layoutPriority(1)
                .padding(.leading, Metrics.Spacing.s - Metrics.Spacing.xxs)
            Spacer(minLength: Metrics.Spacing.xs)
            HStack(spacing: Metrics.Spacing.xs) {
                trailing
            }
        }
        .padding(.leading, CGFloat(depth) * Metrics.Indent.level)
        .frame(height: Metrics.Row.sidebar)
        .contentShape(Rectangle())
    }

    static var insets: EdgeInsets {
        EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
    }
}

struct WarningBadge: View {
    var body: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: Metrics.Icon.warningBadge, weight: .bold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(Palette.Status.onFill.color, Palette.Status.conflict.ink.color)
    }
}

private struct DisclosureSlot: View {
    let isExpanded: Bool?

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: Metrics.Icon.disclosure, weight: .bold))
            .foregroundStyle(Palette.Text.secondary.color)
            .rotationEffect(.degrees(isExpanded == true ? 90 : 0))
            .frame(width: Metrics.Indent.disclosure)
            .opacity(isExpanded == nil ? 0 : 1)
            .accessibilityHidden(true)
    }
}

private struct Destination: View {
    let viewModel: RepositoryViewModel
    let title: String
    let systemImage: String
    let pane: RepositoryViewModel.Pane
    var count = 0
    @State private var isHovered = false

    var body: some View {
        let isSelected = viewModel.sidebarSelection == .pane(pane)
        let ink = isSelected ? Palette.Accent.text.color : Palette.Text.primary.color
        HStack(spacing: 0) {
            DisclosureSlot(isExpanded: nil)
            Image(systemName: systemImage)
                .font(.system(size: Metrics.Sidebar.destinationIcon, weight: .regular))
                .foregroundStyle(isSelected ? ink : Palette.Text.secondary.color)
                .frame(width: Metrics.Sidebar.iconColumn, alignment: .center)
                .padding(.leading, Metrics.Spacing.xxs)
            Text(title)
                .font(Metrics.Font.title.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(ink)
                .lineLimit(1)
                .padding(.leading, Metrics.Spacing.s - Metrics.Spacing.xxs)
            Spacer(minLength: Metrics.Spacing.xs)
            if count > 0 {
                CountBadge(count: count)
            }
        }
        .frame(height: Metrics.Sidebar.destinationRow)
        .contentShape(Rectangle())
        .background {
            RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous)
                .fill(isSelected ? Palette.Accent.tint.color : Palette.Text.primary.color.opacity(isHovered ? Palette.Ink.hover : 0))
                .padding(.horizontal, -(Metrics.Sidebar.listInset - Metrics.Sidebar.selectionInset))
        }
        .onHover { isHovered = $0 }
        .onTapGesture { viewModel.selectSidebar(.pane(pane)) }
        .accessibilityElement(children: .ignore)
        .accessibilityAction { viewModel.selectSidebar(.pane(pane)) }
        .accessibilityLabel(count > 0 ? "\(title) (\(count))" : title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("pane.\(pane.id)")
    }
}

private struct DetachedHeadRow: View {
    let commit: Commit

    var body: some View {
        SidebarRow(systemImage: "exclamationmark.triangle.fill", tint: Palette.Status.conflict.ink.color) {
            Text("HEAD detached at \(commit.shortHash)")
                .fontWeight(.semibold)
        } trailing: {
            EmptyView()
        }
        .help("No branch is checked out. New commits belong to no branch: create a branch here to keep them.")
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("sidebar.detachedHead")
    }
}

struct FolderRow: View {
    let row: BranchOutline.Row
    let systemImage: String
    let isExpanded: Bool
    let identifier: String
    let toggle: () -> Void

    var body: some View {
        SidebarRow(systemImage: systemImage, depth: row.depth, disclosure: isExpanded) {
            Text(row.node.name)
        } trailing: {
            EmptyView()
        }
        .sidebarItemChrome()
        .onTapGesture(perform: toggle)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { toggle() }
        .accessibilityIdentifier("\(identifier).\(BranchOutline.path(ofFolder: row.id))")
        .accessibilityValue(isExpanded ? "expanded" : "collapsed")
    }
}

struct BranchRow: View {
    let branch: Branch
    let title: String
    let depth: Int
    let selection: RepositoryViewModel.SidebarSelection
    let viewModel: RepositoryViewModel

    var body: some View {
        BranchRowContent(branch: branch, title: title, depth: depth, selection: selection, viewModel: viewModel)
            .equatable()
            .sidebarItemChrome(selection, trailingInset: BranchRowContent.actionsWidth)
            .tag(selection)
    }
}

private struct BranchRowContent: View, Equatable {
    let branch: Branch
    let title: String
    let depth: Int
    let selection: RepositoryViewModel.SidebarSelection
    let viewModel: RepositoryViewModel
    @State private var isHovered = false

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.branch == rhs.branch && lhs.title == rhs.title && lhs.depth == rhs.depth && lhs.selection == rhs.selection && lhs.viewModel === rhs.viewModel
    }

    var body: some View {
        let isSelected = viewModel.sidebarItem == selection
        let isPinned = viewModel.isPinned(branch)
        let isFiltered = viewModel.isFiltered(to: branch)
        let isHidden = viewModel.isHidden(branch)
        let keepsActions = isPinned || isFiltered || isHidden
        HStack(spacing: 0) {
            SidebarRow(
                systemImage: branch.isCurrent ? "checkmark" : "arrow.triangle.branch",
                tint: branch.isCurrent ? Palette.Accent.text.color : Palette.Text.secondary.color,
                iconWeight: branch.isCurrent ? .bold : .regular,
                depth: depth,
                warning: branch.isUpstreamGone ? "Upstream \(branch.upstream ?? "") is gone" : nil
            ) {
                Text(title)
                    .fontWeight(branch.isCurrent ? .semibold : .regular)
            } trailing: {
                if let summary = branch.trackSummary {
                    Text(summary)
                        .font(Metrics.Font.monoCaption)
                        .foregroundStyle(Palette.Text.secondary.color)
                }
            }
            .opacity(isHidden ? Metrics.Opacity.dimmed : 1)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("branch.\(branch.name)")
            .accessibilityValue(branch.isCurrent ? "current" : "")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .padding(.trailing, keepsActions ? Self.actionsWidth : 0)
        }
        .overlay(alignment: .trailing) {
            if isHovered || keepsActions {
                BranchActions(branch: branch, viewModel: viewModel, isHovered: isHovered, isPinned: isPinned, isFiltered: isFiltered, isHidden: isHidden)
                    .background {
                        if !keepsActions {
                            ZStack {
                                Palette.Surface.sidebar.color
                                SelectionHighlight(isSelected: isSelected, isHovered: true)
                            }
                        }
                    }
            }
        }
        .frame(height: Metrics.Row.sidebar)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .linkCursor()
    }

    fileprivate static let actionsWidth = Metrics.HitTarget.inline * 3 + Metrics.Spacing.xs
}

private struct BranchActions: View {
    let branch: Branch
    let viewModel: RepositoryViewModel
    let isHovered: Bool
    let isPinned: Bool
    let isFiltered: Bool
    let isHidden: Bool

    var body: some View {
        HStack(spacing: 0) {
            BranchActionButton(
                title: isPinned ? "Unpin" : "Pin to Top",
                systemImage: isPinned ? "pin.fill" : "pin",
                isOn: isPinned,
                isVisible: isHovered || isPinned,
                identifier: "branch.\(branch.name).pin"
            ) { Task { await viewModel.togglePin(branch) } }
            BranchActionButton(
                title: isFiltered ? "Remove Branch from History Filter" : "Add Branch to History Filter",
                systemImage: "line.3.horizontal.decrease",
                isOn: isFiltered,
                isVisible: isHovered || isFiltered,
                identifier: "branch.\(branch.name).filter"
            ) { Task { await viewModel.toggleHistoryFilter(branch) } }
            BranchActionButton(
                title: isHidden ? "Show in History" : "Hide in History",
                systemImage: isHidden ? "eye.slash" : "eye",
                isOn: isHidden,
                isVisible: isHovered || isHidden,
                identifier: "branch.\(branch.name).visibility"
            ) { Task { await viewModel.toggleHidden(branch) } }
        }
    }
}

private struct BranchActionButton: View {
    let title: String
    let systemImage: String
    let isOn: Bool
    let isVisible: Bool
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: Metrics.Icon.small, weight: .medium))
                .foregroundStyle(isOn ? Palette.Accent.text.color : Palette.Text.secondary.color)
                .frame(width: Metrics.HitTarget.inline, height: Metrics.HitTarget.inline)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .accessibilityHidden(!isVisible)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "on" : "off")
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}

private struct StashRow: View {
    let stash: Stash

    var body: some View {
        let label = StashLabel(message: stash.message)
        SidebarRow(systemImage: "archivebox") {
            Text(label.title)
        } trailing: {
            if let branch = label.branch {
                SidebarCaption(text: branch)
            }
        }
        .help(stash.message)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("stash.\(stash.reference)")
    }
}

struct SidebarCaption: View {
    let text: String
    var tint = Palette.Text.secondary.color
    var truncation: Text.TruncationMode = .tail

    var body: some View {
        Text(text)
            .font(Metrics.Font.caption)
            .foregroundStyle(tint)
            .lineLimit(1)
            .truncationMode(truncation)
    }
}

private struct SidebarSelectionSync: View {
    let viewModel: RepositoryViewModel
    let marks: SidebarSelectionMarks

    var body: some View {
        Color.clear
            .onChange(of: viewModel.sidebarSelection, initial: true) { _, selection in
                if !marks.items.contains(selection) { marks.set([selection]) }
            }
            .onChange(of: viewModel.localBranches) { _, branches in
                let names = Set(branches.map(\.name))
                marks.set(marks.items.filter { item in
                    if case let .branch(name) = item { return names.contains(name) }
                    return true
                })
            }
    }
}

enum SidebarPrimaryAction {
    static func activates(for event: NSEvent?) -> Bool {
        event?.type == .keyDown
    }
}

struct SidebarItemChrome: ViewModifier {
    let selection: RepositoryViewModel.SidebarSelection?
    var trailingInset: CGFloat = 0
    @Environment(\.sidebarSelectionMarks) private var marks
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background {
                if let selection, let marks {
                    SidebarRowAnchor(selection: selection, trailingInset: trailingInset, marks: marks)
                }
            }
            .onHover { isHovered = $0 }
            .listRowBackground(
                SelectionHighlight(isSelected: selection.flatMap { marks?.mark(for: $0).isSelected } ?? false, isHovered: isHovered)
                    .padding(.horizontal, Metrics.Sidebar.selectionInset)
            )
    }
}

extension View {
    func sidebarItemChrome(_ selection: RepositoryViewModel.SidebarSelection? = nil, trailingInset: CGFloat = 0) -> some View {
        modifier(SidebarItemChrome(selection: selection, trailingInset: trailingInset))
    }
}

struct InkSelectionTableStyle: NSViewRepresentable {
    func makeNSView(context: Context) -> StylerView {
        StylerView()
    }

    func updateNSView(_ view: StylerView, context: Context) {
        view.apply()
    }

    final class StylerView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
            DispatchQueue.main.async { [weak self] in self?.apply() }
        }

        override func layout() {
            super.layout()
            apply()
        }

        func apply() {
            var ancestor = superview
            while let view = ancestor, !(view is NSTableView) { ancestor = view.superview }
            guard let table = ancestor as? NSTableView, table.selectionHighlightStyle != .none else { return }
            table.selectionHighlightStyle = .none
        }
    }
}

public enum SidebarSections {
    public static let collapsedByDefault: Set<String> = ["remotes", "tags"]
}

private struct ActiveRepositoryTabKey: EnvironmentKey {
    static let defaultValue = true
}

private struct SidebarExpandsAllSectionsKey: EnvironmentKey {
    static let defaultValue = false
}

private struct SidebarSelectionMarksKey: EnvironmentKey {
    static let defaultValue: SidebarSelectionMarks? = nil
}

extension EnvironmentValues {
    var isActiveRepositoryTab: Bool {
        get { self[ActiveRepositoryTabKey.self] }
        set { self[ActiveRepositoryTabKey.self] = newValue }
    }

    var sidebarSelectionMarks: SidebarSelectionMarks? {
        get { self[SidebarSelectionMarksKey.self] }
        set { self[SidebarSelectionMarksKey.self] = newValue }
    }

    public var sidebarExpandsAllSections: Bool {
        get { self[SidebarExpandsAllSectionsKey.self] }
        set { self[SidebarExpandsAllSectionsKey.self] = newValue }
    }
}
