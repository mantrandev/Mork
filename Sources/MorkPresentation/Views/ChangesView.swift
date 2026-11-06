import MorkDomain
import SwiftUI

struct ChangesView: View {
    @Bindable var viewModel: RepositoryViewModel
    @State private var pendingDiscard: [FileChange] = []

    var body: some View {
        Group {
            if viewModel.hasLoaded && viewModel.changes.isEmpty {
                EmptyStateView("Working Tree Clean", systemImage: "checkmark", message: "No uncommitted changes.")
                    .accessibilityIdentifier("changes.clean")
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: Metrics.Spacing.xs) {
                        SearchField(prompt: "Filter files", text: $viewModel.changesFilter, identifier: "changes.filter")
                        ChangesHeaderActions(viewModel: viewModel)
                    }
                    .frame(height: Metrics.Control.searchField)
                    .padding(.leading, Metrics.Spacing.s)
                    .padding(.trailing, Metrics.Spacing.xs)
                    .padding(.top, Metrics.Spacing.s)
                    .padding(.bottom, Metrics.Spacing.s - Metrics.Spacing.xxs)
                    Hairline()
                    ConflictsSection(viewModel: viewModel)
                    VSplitView {
                        ChangeList(
                            title: "Unstaged",
                            count: viewModel.unstagedChanges.count - viewModel.conflictedChanges.count,
                            action: "Stage all",
                            identifier: "changes.stageAll",
                            perform: { Task { await viewModel.stageAll() } }
                        ) {
                            unstagedTable
                        }
                        ChangeList(
                            title: "Staged",
                            count: viewModel.stagedChanges.count,
                            action: "Unstage all",
                            identifier: "changes.unstageAll",
                            perform: { Task { await viewModel.unstageAll() } }
                        ) {
                            stagedTable
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("changes.list")
            }
        }
        .morkConfirmation(isPresented: Binding(get: { !pendingDiscard.isEmpty }, set: { if !$0 { pendingDiscard = [] } })) {
            discardConfirmation(pendingDiscard)
        }
    }

    private func discardConfirmation(_ changes: [FileChange]) -> MorkConfirmation {
        MorkConfirmation(
            kind: .destructive,
            title: changes.count == 1 ? "Discard all unstaged changes in \(changes.first?.path ?? "")?" : "Discard unstaged changes in \(changes.count) files?",
            message: "Tracked files go back to their staged version and untracked files are deleted from disk. Git keeps no copy of either, so this cannot be undone.",
            commands: DialogCommands.discard(changes),
            actions: [DialogAction(title: "Discard", isDestructive: true, isDefault: true, identifier: "discard.confirm") { Task { await viewModel.discard(changes) } }]
        )
    }

    private var unstagedTable: some View {
        ChangeFileTable(
            changes: viewModel.visibleUnstagedChanges,
            rows: viewModel.unstagedChangeRows,
            staged: false,
            animationTick: viewModel.stagingTick,
            selectedPath: selectedPath(staged: false),
            identifier: "changes.unstaged",
            isLFS: { viewModel.isLFSFile($0) },
            onSelect: { select($0, staged: false) },
            onToggle: { toggle($0, staged: false) },
            onDoubleClick: { change in toggle(change, staged: false) },
            menu: unstagedMenu,
            selectedPaths: viewModel.selectedUnstagedRowIDs,
            onSelection: { viewModel.selectChangeRows($0, staged: false) },
            onDiscard: { requestDiscard(viewModel.selectedChanges(staged: false)) },
            onPreview: preview,
            onClosePreview: closePreview,
            onToggleSelection: { changes in toggleKeepingPosition(changes, staged: false) },
            onToggleFolder: { viewModel.toggleChangesFolder($0, staged: false) },
            onToggleFolderStaging: { path in Task { await viewModel.toggleFolderStaging(path, staged: false) } },
            onHover: { viewModel.hoverChange($0, staged: false) },
            showsLocation: isCombined
        )
        .id(isCombined)
    }

    private var isCombined: Bool { viewModel.changeListOptions.isCombined }

    private var stagedTable: some View {
        ChangeFileTable(
            changes: viewModel.visibleStagedChanges,
            rows: viewModel.stagedChangeRows,
            staged: true,
            animationTick: viewModel.stagingTick,
            selectedPath: selectedPath(staged: true),
            identifier: "changes.staged",
            isLFS: { viewModel.isLFSFile($0) },
            onSelect: { select($0, staged: true) },
            onToggle: { toggle($0, staged: true) },
            onDoubleClick: { change in toggle(change, staged: true) },
            menu: stagedMenu,
            selectedPaths: viewModel.selectedStagedRowIDs,
            onSelection: { viewModel.selectChangeRows($0, staged: true) },
            onPreview: preview,
            onClosePreview: closePreview,
            onToggleSelection: { changes in toggleKeepingPosition(changes, staged: true) },
            onToggleFolder: { viewModel.toggleChangesFolder($0, staged: true) },
            onToggleFolderStaging: { path in Task { await viewModel.toggleFolderStaging(path, staged: true) } },
            onHover: { viewModel.hoverChange($0, staged: true) },
            showsLocation: isCombined
        )
        .id(isCombined)
    }

    private func toggle(_ change: FileChange, staged: Bool) {
        toggle(id: change.path, staged: staged)
    }

    private func toggle(id: String, staged: Bool) {
        let items = Set(viewModel.selectedChanges(staged: staged, clicked: id).map { RepositoryViewModel.Selection.file($0, staged: staged) })
        Task { await viewModel.toggleStaging(items) }
    }

    private func toggleKeepingPosition(_ changes: [FileChange], staged: Bool) {
        Task { await viewModel.toggleStagingKeepingPosition(changes, staged: staged) }
    }

    private func selectedPath(staged: Bool) -> String? {
        guard case let .file(change, isStaged) = viewModel.selection, isStaged == staged else { return nil }
        return change.path
    }

    private func select(_ change: FileChange?, staged: Bool) {
        if let change {
            viewModel.selection = .file(change, staged: staged)
        } else if selectedPath(staged: staged) != nil {
            viewModel.selection = nil
        }
    }

    @ViewBuilder
    private func unstagedMenu(_ change: FileChange) -> some View {
        Button("Stage") { toggle(change, staged: false) }
        Button("Discard Changes…", role: .destructive) { requestDiscard(viewModel.selectedChanges(staged: false, clicked: change.path)) }
            .disabled(change.isIgnored)
            .accessibilityIdentifier("discard.\(change.path)")
        IgnoreMenu(viewModel: viewModel, change: change)
        Divider()
        IntegrationFileMenu(viewModel: viewModel, path: change.path, diffTarget: change.isUntracked ? nil : .unstaged, canOpenFile: change.worktree != "D")
        Divider()
        FileInspectionMenu(viewModel: viewModel, path: change.path, isTracked: !change.isUntracked)
        LFSFileMenu(viewModel: viewModel, path: change.path)
        CustomCommandsMenu(viewModel: viewModel, location: .file, file: change.path)
    }

    @ViewBuilder
    private func stagedMenu(_ change: FileChange) -> some View {
        Button("Unstage") { toggle(change, staged: true) }
        Divider()
        IntegrationFileMenu(viewModel: viewModel, path: change.path, diffTarget: .staged)
        Divider()
        FileInspectionMenu(viewModel: viewModel, path: change.path, isTracked: change.index != "A")
        LFSFileMenu(viewModel: viewModel, path: change.path)
        CustomCommandsMenu(viewModel: viewModel, location: .file, file: change.path)
    }

    private func preview(isSingleFile: Bool) {
        guard isSingleFile || viewModel.isPreviewingFile else { return }
        viewModel.toggleFilePreview()
    }

    private func closePreview() -> Bool {
        guard viewModel.isPreviewingFile else { return false }
        viewModel.closeFilePreview()
        return true
    }

    private func requestDiscard(_ changes: [FileChange]) {
        guard !changes.isEmpty else { return }
        if viewModel.confirmsDestructiveActions {
            pendingDiscard = changes
        } else {
            Task { await viewModel.discard(changes) }
        }
    }
}

struct CommitComposer: View {
    @Bindable var viewModel: RepositoryViewModel
    @FocusState private var focus: Field?

    private enum Field {
        case subject
        case description
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.s) {
            HStack(spacing: Metrics.Spacing.s) {
                TextField("Commit subject", text: $viewModel.commitSubject, prompt: Text("Commit subject").foregroundStyle(Palette.Text.tertiary.color))
                    .textFieldStyle(.plain)
                    .font(Metrics.Font.title)
                    .foregroundStyle(Palette.Text.primary.color)
                    .focused($focus, equals: .subject)
                    .accessibilityIdentifier("commit.message")
                Text("\(viewModel.commitSubject.count)/\(CommitMessage.recommendedSubjectLength)")
                    .font(Metrics.Font.monoCaption)
                    .foregroundStyle(viewModel.isSubjectTooLong ? Palette.Status.conflict.ink.color : Palette.Text.tertiary.color)
                    .accessibilityIdentifier("commit.subjectCount")
            }
            .padding(.horizontal, Metrics.Spacing.s)
            .frame(height: Metrics.Control.regular)
            .fieldChrome(isFocused: focus == .subject)
            if viewModel.isSubjectTooLong {
                Label("Subject is longer than \(CommitMessage.recommendedSubjectLength) characters.", systemImage: "exclamationmark.triangle")
                    .font(Metrics.Font.caption)
                    .foregroundStyle(Palette.Status.conflict.ink.color)
                    .accessibilityIdentifier("commit.subjectWarning")
            }
            TextEditor(text: $viewModel.commitDescription)
                .font(Metrics.Font.title)
                .foregroundStyle(Palette.Text.primary.color)
                .scrollContentBackground(.hidden)
                .focused($focus, equals: .description)
                .padding(.horizontal, Metrics.Spacing.xs)
                .padding(.vertical, Metrics.Spacing.xs + Metrics.Spacing.xxs)
                .frame(height: Metrics.Composer.descriptionHeight)
                .fieldChrome(isFocused: focus == .description)
                .accessibilityIdentifier("commit.description")
                .overlay(alignment: .topLeading) {
                    if viewModel.commitDescription.isEmpty {
                        Text("Description")
                            .font(Metrics.Font.title)
                            .foregroundStyle(Palette.Text.tertiary.color)
                            .padding(.leading, Metrics.Spacing.s + Metrics.Line.hairline)
                            .padding(.top, Metrics.Spacing.xs + Metrics.Spacing.xxs)
                            .allowsHitTesting(false)
                    }
                }
            HStack(spacing: Metrics.Spacing.m) {
                Toggle("Amend", isOn: Binding(get: { viewModel.isAmending }, set: { value in Task { await viewModel.setAmending(value) } }))
                    .toggleStyle(.checkbox)
                    .font(Metrics.Font.title)
                    .foregroundStyle(Palette.Text.primary.color)
                    .accessibilityIdentifier("commit.amend")
                Spacer()
                Button {
                    Task { await viewModel.commit() }
                } label: {
                    HStack(spacing: Metrics.Spacing.s) {
                        Text(commitTitle)
                            .fontWeight(.semibold)
                        Text("⌘↩")
                            .font(Metrics.Font.monoCaption)
                            .opacity(Metrics.Opacity.hint)
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(.morkPrimary)
                .disabled(!viewModel.canCommit)
                .accessibilityLabel(commitTitle)
                .accessibilityIdentifier("commit.button")
            }
        }
        .padding(Metrics.Spacing.m)
        .background(Palette.Surface.raised.color)
    }

    private var commitTitle: String {
        if viewModel.isAmending { return "Amend Last Commit" }
        let count = viewModel.stagedChanges.count
        return "Commit \(count) \(count == 1 ? "File" : "Files")"
    }
}

private struct ChangesHeaderActions: View {
    @Bindable var viewModel: RepositoryViewModel

    var body: some View {
        let direction = viewModel.stageAllDirection
        DiffBarButton(systemImage: (direction ?? .stage).systemImage, help: (direction ?? .stage).title, identifier: "changes.stageToggle") {
            Task { await viewModel.toggleStageAll() }
        }
        .disabled(direction == nil)
        DiffBarButton(systemImage: "eye", help: "Preview", identifier: "changes.preview", isOn: viewModel.isPreviewingFile || viewModel.conflictWindowPath != nil) {
            viewModel.toggleFilePreview()
        }
        .disabled(viewModel.selectedFilePath == nil)
        Menu {
            Toggle("View as Tree", isOn: mode(.tree, combined: false))
            Toggle("View as List", isOn: mode(.flat, combined: false))
            Toggle("View as Combined List", isOn: mode(.flat, combined: true))
                .help("Name and Location columns")
            Divider()
            Toggle("Hide Untracked Files", isOn: $viewModel.changeListOptions.hidesUntracked)
            Toggle("Show Ignored Files", isOn: $viewModel.changeListOptions.showsIgnored)
        } label: {
            Image(systemName: "list.bullet")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .frame(width: Metrics.HitTarget.inline, height: Metrics.HitTarget.inline)
        .help("View Options")
        .accessibilityLabel("View Options")
        .accessibilityValue(viewModel.changesListMode.rawValue)
        .accessibilityIdentifier("changes.viewOptions")
    }

    private func mode(_ mode: FileListMode, combined: Bool) -> Binding<Bool> {
        Binding(
            get: { viewModel.changesListMode == mode && viewModel.changeListOptions.isCombined == combined },
            set: { _ in
                viewModel.changesListMode = mode
                viewModel.changeListOptions.isCombined = combined
            }
        )
    }
}

private struct ChangeList<Content: View>: View {
    let title: String
    let count: Int
    let action: String
    let identifier: String
    let perform: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: title, count: count) {
                Button(action, action: perform)
                    .buttonStyle(.mork(.secondary, size: .small))
                    .disabled(count == 0)
                    .accessibilityIdentifier(identifier)
            }
            .background(Palette.Surface.sidebar.color)
            Hairline()
            content
                .listStyle(.plain)
                .environment(\.defaultMinListRowHeight, Metrics.Row.list)
        }
        .frame(minHeight: Metrics.Panel.header + Metrics.Row.list * 2, maxHeight: .infinity)
    }
}
