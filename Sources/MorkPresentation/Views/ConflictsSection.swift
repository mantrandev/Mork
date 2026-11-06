import MorkDomain
import SwiftUI

struct ConflictsSection: View {
    @Bindable var viewModel: RepositoryViewModel
    @State private var pendingDelete: FileChange?
    @FocusState private var isListFocused: Bool

    var body: some View {
        if viewModel.hasConflicts {
            VStack(spacing: 0) {
                PanelHeader(title: "Conflicts", count: viewModel.conflictedChanges.count, tint: Palette.Status.conflict.ink.color) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Palette.Status.conflict.ink.color)
                } trailing: {
                    Text("Select a file to resolve it")
                        .font(Metrics.Font.caption)
                        .foregroundStyle(Palette.Text.secondary.color)
                }
                .background(Palette.Surface.raised.color)
                .overlay(alignment: .leading) {
                    Palette.Status.conflict.ink.color.frame(width: Metrics.Conflict.accentBar)
                }
                Divider()
                List(selection: $viewModel.selection) {
                    ForEach(viewModel.visibleConflictedChanges) { change in
                        ConflictRow(change: change)
                            .tag(RepositoryViewModel.Selection.file(change, staged: false))
                            .contextMenu { menu(for: change) }
                            .listRowInsets(Metrics.listRowInsets)
                    }
                }
                .listStyle(.plain)
                .environment(\.defaultMinListRowHeight, Metrics.Row.list)
                .focused($isListFocused)
                .onChange(of: viewModel.selection) {
                    if viewModel.selectedConflict != nil, !isListFocused { isListFocused = true }
                }
                .onKeyPress(.space, action: toggleWindow)
                .onKeyPress(.return, action: toggleWindow)
                .onKeyPress(.escape) {
                    guard viewModel.conflictWindowPath != nil else { return .ignored }
                    viewModel.closeConflictWindow()
                    return .handled
                }
                .frame(height: min(CGFloat(max(viewModel.visibleConflictedChanges.count, 1)) * Metrics.Row.list + Metrics.Spacing.s, Metrics.Row.list * 7))
                .accessibilityIdentifier("conflicts.list")
                Divider()
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("conflicts.section")
            .morkConfirmation(item: $pendingDelete) { change in
                .deleteConflictedFile(change.path, identifier: "conflicts.delete.confirm") { Task { await viewModel.resolve(change, using: .delete) } }
            }
        }
    }

    private func toggleWindow() -> KeyPress.Result {
        guard viewModel.conflictWindowPath != nil || viewModel.selectedConflict != nil else { return .ignored }
        viewModel.toggleConflictWindow()
        return .handled
    }

    @ViewBuilder
    private func menu(for change: FileChange) -> some View {
        ForEach(change.conflictKind?.resolutions ?? [], id: \.self) { resolution in
            Button(resolution.title, role: resolution == .delete ? .destructive : nil) {
                if resolution == .delete {
                    pendingDelete = change
                } else {
                    Task { await viewModel.resolve(change, using: resolution) }
                }
            }
            .help(resolution.command(for: change.path))
        }
        if change.conflictKind?.hasContentConflict == true {
            Button("Open in \(viewModel.mergeToolName ?? "Merge Tool")") { viewModel.openInMergeTool(change) }
                .disabled(viewModel.externalTools.run(for: change.path) != nil)
                .accessibilityIdentifier("conflicts.mergeTool.\(change.path)")
        }
        Divider()
        FileInspectionMenu(viewModel: viewModel, path: change.path, isTracked: true)
    }
}

private struct ConflictRow: View {
    let change: FileChange

    var body: some View {
        HStack(spacing: Metrics.ChangeRow.gap) {
            StatusBadge(letter: "U", color: Palette.Status.conflict.ink.color)
            FileIcon(path: change.path)
            FilePathText(path: change.path, originalPath: change.originalPath)
                .font(Metrics.Font.title)
            if let kind = change.conflictKind {
                Text(kind.title)
                    .font(Metrics.Font.caption)
                    .foregroundStyle(Palette.Text.secondary.color)
                    .lineLimit(1)
                    .fixedSize()
                Text(kind.statusCode)
                    .font(Metrics.Font.monoBadge)
                    .foregroundStyle(Palette.Status.conflict.ink.color)
                    .padding(.horizontal, Metrics.Spacing.xs)
                    .frame(height: Metrics.Control.badge)
                    .background(Palette.Status.conflict.tint.color, in: RoundedRectangle(cornerRadius: Metrics.Radius.badge, style: .continuous))
            }
        }
        .frame(height: Metrics.Row.list)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("conflict.\(change.path)")
    }
}

extension ConflictFileResolution {
    func command(for path: String) -> String {
        let quoted = ShellWords.quote(path)
        return switch self {
        case .ours: "git checkout --ours -- \(quoted) && git add -- \(quoted)"
        case .theirs: "git checkout --theirs -- \(quoted) && git add -- \(quoted)"
        case .keep: "git add -- \(quoted)"
        case .delete: "git rm -- \(quoted)"
        }
    }
}
