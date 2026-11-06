import AppKit
import MorkDomain
import SwiftUI

struct RepositoryManagerView: View {
    let app: AppViewModel
    @Bindable var manager: RepositoryManagerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let warning = manager.warning {
                HStack(alignment: .top, spacing: Metrics.Spacing.s) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Palette.Status.conflict.ink.color)
                    Text(warning)
                        .font(Metrics.Font.caption)
                        .foregroundStyle(Palette.Text.primary.color)
                        .textSelection(.enabled)
                    Spacer()
                    Button("Dismiss") { manager.warning = nil }
                        .buttonStyle(.mork(.secondary, size: .small))
                }
                .padding(Metrics.Spacing.s)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("welcome.warning")
            }
            List(selection: $manager.selection) {
                ForEach(manager.groups) { group in
                    Section {
                        RepositoryGroupRows(app: app, manager: manager, group: group)
                    } header: {
                        RepositoryGroupHeader(manager: manager, group: group)
                    }
                }
            }
            .listStyle(.sidebar)
            .environment(\.defaultMinListRowHeight, Metrics.Row.list)
            .scrollContentBackground(.hidden)
            .contextMenu(forSelectionType: RepositoryManagerSelection.self) { items in
                if items.count == 1, let item = items.first {
                    Button("Open") { Task { await app.openManaged(at: item.url) } }
                    Divider()
                    Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
                    Button("Copy Path") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(item.url.path, forType: .string)
                    }
                }
            } primaryAction: { items in
                guard let item = items.first else { return }
                Task { await app.openManaged(at: item.url) }
            }
            .accessibilityIdentifier("welcome.list")
            Divider()
            HStack(spacing: Metrics.Spacing.s) {
                Button("Add Folder…") { Task { await manager.addFolder() } }
                    .buttonStyle(.mork(.secondary, size: .small))
                    .help("Scan a folder for Git repositories")
                    .accessibilityIdentifier("welcome.addFolder")
                Button("Rescan") { Task { await manager.rescan() } }
                    .buttonStyle(.mork(.secondary, size: .small))
                    .disabled(manager.folders.isEmpty || manager.isScanning)
                    .accessibilityIdentifier("welcome.rescan")
                if manager.isScanning {
                    ProgressView().controlSize(.small)
                        .accessibilityIdentifier("welcome.scanning")
                }
                Spacer()
            }
            .controlSize(.small)
            .padding(Metrics.Spacing.s)
        }
    }
}

private struct RepositoryGroupHeader: View {
    let manager: RepositoryManagerViewModel
    let group: RepositoryGroup

    private var isRecent: Bool { group.folder == nil }

    var body: some View {
        HStack(spacing: Metrics.Spacing.s) {
            Text(isRecent ? "Recent Repositories" : group.title)
                .font(Metrics.Font.body.weight(.semibold))
                .foregroundStyle(Palette.Text.secondary.color)
            if let folder = group.folder {
                Text(RecentLocation.title(for: folder))
                    .font(Metrics.Font.caption)
                    .foregroundStyle(Palette.Text.secondary.color)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button {
                    manager.removeFolder(folder)
                } label: {
                    Image(systemName: "xmark.circle")
                        .frame(width: Metrics.HitTarget.icon, height: Metrics.HitTarget.icon)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.Text.secondary.color)
                .help("Remove this folder from the Repository Manager")
                .accessibilityLabel("Remove \(group.title)")
                .accessibilityIdentifier("welcome.group.\(group.title).remove")
            }
        }
        .frame(minHeight: Metrics.Row.list)
        .contextMenu {
            if let folder = group.folder {
                Button("Rescan") { Task { await manager.rescan() } }
                Button("Remove Folder") { manager.removeFolder(folder) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(isRecent ? "welcome.recents" : "welcome.group.\(group.title)")
    }
}

private struct RepositoryGroupRows: View {
    let app: AppViewModel
    let manager: RepositoryManagerViewModel
    let group: RepositoryGroup

    private var isRecent: Bool { group.folder == nil }

    var body: some View {
        if group.repositories.isEmpty {
            Text("No Git repositories found in this folder.")
                .font(Metrics.Font.caption)
                .foregroundStyle(Palette.Text.secondary.color)
        }
        ForEach(group.repositories, id: \.url) { repository in
            RepositoryManagerRow(app: app, manager: manager, repository: repository, identifier: isRecent ? "welcome.recent.\(repository.name)" : "welcome.repo.\(repository.name)")
                .tag(RepositoryManagerSelection(group: group.id, url: repository.url))
        }
    }
}

private struct RepositoryManagerRow: View {
    let app: AppViewModel
    let manager: RepositoryManagerViewModel
    let repository: DiscoveredRepository
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.xxs) {
            HStack(spacing: Metrics.ChangeRow.gap) {
                Button {
                    Task { await manager.toggleWorktrees(for: repository.url) }
                } label: {
                    Image(systemName: manager.isExpanded(repository.url) ? "chevron.down" : "chevron.right")
                        .font(.system(size: Metrics.Icon.disclosure, weight: .semibold))
                        .frame(width: Metrics.HitTarget.inline, height: Metrics.HitTarget.inline)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.Text.secondary.color)
                .opacity(repository.isBare ? 0 : 1)
                .disabled(repository.isBare)
                .help("Show worktrees")
                .accessibilityIdentifier("\(identifier).worktrees")
                Image(systemName: repository.isBare ? "server.rack" : "folder")
                    .font(.system(size: Metrics.Icon.regular))
                    .foregroundStyle(Palette.Text.secondary.color)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Metrics.Spacing.xxs) {
                    HStack(spacing: Metrics.Spacing.s) {
                        Text(repository.name)
                            .font(Metrics.Font.title)
                            .foregroundStyle(Palette.Text.primary.color)
                            .lineLimit(1)
                            .layoutPriority(1)
                            .accessibilityLabel("\(repository.name), \(location)")
                            .accessibilityIdentifier(identifier)
                        Spacer()
                        trailing
                    }
                    Text(location)
                        .font(Metrics.Font.caption)
                        .foregroundStyle(Palette.Text.secondary.color)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            if manager.isExpanded(repository.url) {
                worktrees
                    .padding(.leading, Metrics.HitTarget.inline + Metrics.Spacing.s)
            }
        }
        .task(id: repository.url) { await manager.loadStatus(for: repository.url) }
    }

    @ViewBuilder
    private var trailing: some View {
        if repository.isBare {
            Text("bare")
                .font(Metrics.Font.caption)
                .foregroundStyle(Palette.Text.secondary.color)
                .accessibilityIdentifier("\(identifier).bare")
        } else if let status = manager.status(of: repository.url) {
            ViewThatFits(in: .horizontal) {
                statusChip(status, showsBranch: true)
                statusChip(status, showsBranch: false)
            }
            .foregroundStyle(Palette.Text.secondary.color)
            .help(status.branch)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("\(identifier).status")
        }
    }

    private func statusChip(_ status: RepositoryStatusSummary, showsBranch: Bool) -> some View {
        HStack(spacing: Metrics.Spacing.xs) {
            if status.isDirty {
                Circle()
                    .fill(Palette.Status.modified.ink.color)
                    .frame(width: Metrics.Manager.statusDot, height: Metrics.Manager.statusDot)
                    .help("Uncommitted changes to tracked files")
                    .accessibilityLabel("changed")
            }
            if showsBranch {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: Metrics.Icon.small))
                Text(status.branch)
                    .font(Metrics.Font.caption)
            } else {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: Metrics.Icon.small))
                    .accessibilityLabel(status.branch)
            }
        }
    }

    private var location: String {
        RecentLocation.title(for: repository.url)
    }

    @ViewBuilder
    private var worktrees: some View {
        switch manager.worktrees(of: repository.url) {
        case .idle, .loading:
            ProgressView().controlSize(.small)
        case let .failed(message):
            Text(message)
                .font(Metrics.Font.caption)
                .foregroundStyle(Palette.Status.deleted.ink.color)
        case let .loaded(list):
            let linked = list.filter { !$0.isMain && !$0.isBare }
            if linked.isEmpty {
                Text("No linked worktrees")
                    .font(Metrics.Font.caption)
                    .foregroundStyle(Palette.Text.secondary.color)
            }
            ForEach(linked) { worktree in
                Button { Task { await app.openWorktree(worktree) } } label: {
                    HStack(spacing: Metrics.ChangeRow.gap) {
                        Image(systemName: worktree.isPrunable ? "exclamationmark.triangle" : "square.on.square.dashed")
                            .foregroundStyle(worktree.isPrunable ? Palette.Status.conflict.ink.color : Palette.Text.secondary.color)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(worktree.name)
                                .font(Metrics.Font.title)
                                .foregroundStyle(Palette.Text.primary.color)
                            Text(worktree.isPrunable ? "missing folder" : worktree.branch ?? worktree.shortHead.map { "detached at \($0)" } ?? "")
                                .font(Metrics.Font.caption)
                                .foregroundStyle(Palette.Text.secondary.color)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(worktree.isPrunable)
                .accessibilityIdentifier("welcome.worktree.\(worktree.name)")
            }
        }
    }
}
