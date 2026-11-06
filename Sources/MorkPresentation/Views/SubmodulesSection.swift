import AppKit
import MorkDomain
import SwiftUI

struct SubmodulesSection: View {
    let viewModel: RepositoryViewModel
    @Binding var isExpanded: Bool
    @Binding var sheet: WorkspaceSheet?

    var body: some View {
        Group {
            SidebarSectionHeader(title: "Submodules", isExpanded: $isExpanded, addHelp: "Add Submodule…", identifier: "sidebar.addSubmodule") { sheet = .addSubmodule }
                .contextMenu {
                    Button("Add New Submodule…") { sheet = .addSubmodule }
                        .accessibilityIdentifier("submodulesMenu.addSubmodule")
                    Button("Update Submodules") { sheet = .updateSubmodules }
                        .accessibilityIdentifier("submodulesMenu.updateSubmodules")
                }
                .sidebarSectionHeaderRow()
            if isExpanded {
                if viewModel.submodules.isEmpty {
                    SidebarPlaceholder(text: "No submodules", identifier: "sidebar.noSubmodules")
                }
                ForEach(viewModel.submodules) { submodule in
                    SubmoduleRow(submodule: submodule)
                        .sidebarSelectable(.submodule(submodule.path), viewModel: viewModel)
                        .sidebarRowInsets()
                }
            }
        }
    }

}

struct SubmoduleMenu: View {
    let submodule: Submodule
    let viewModel: RepositoryViewModel
    @Binding var sheet: WorkspaceSheet?
    let onOpenRepository: (URL) -> Void

    var body: some View {
        Button("Open as Repository") { Task { await viewModel.activateSidebar(.submodule(submodule.path), openRepository: onOpenRepository) } }
            .disabled(!submodule.isInitialized)
            .accessibilityIdentifier("submoduleMenu.open")
        Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([viewModel.url(of: submodule)]) }
        Divider()
        Button("Update Submodules") { sheet = .updateSubmodules }
            .accessibilityIdentifier("submoduleMenu.update")
        Button("Sync URLs") { Task { await viewModel.syncSubmodules() } }
            .accessibilityIdentifier("submoduleMenu.sync")
        if let url = submodule.url {
            Button("Copy URL") { Pasteboard.copy(url) }
        }
        Button("Copy Commit Hash") { Pasteboard.copy(submodule.commit) }
        Divider()
        Button("Add Submodule…") { sheet = .addSubmodule }
    }
}

private struct SubmoduleRow: View {
    let submodule: Submodule

    var body: some View {
        SidebarRow(systemImage: "shippingbox", tint: tint, depth: submodule.isNested ? 1 : 0) {
            Text(submodule.isNested ? submodule.path : submodule.name)
        } trailing: {
            if let badge {
                SidebarCaption(text: badge, tint: tint)
            }
            Text(submodule.shortCommit)
                .font(Metrics.Font.monoCaption)
                .foregroundStyle(Palette.Text.secondary.color)
        }
        .help(help)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("submodule.\(submodule.path)")
        .accessibilityValue(badge ?? "up to date")
    }

    private var badge: String? {
        switch submodule.state {
        case .current: nil
        case .notInitialized: "not initialized"
        case .outOfSync: "moved"
        case .conflict: "conflict"
        }
    }

    private var tint: Color {
        switch submodule.state {
        case .current: Palette.Text.secondary.color
        case .notInitialized, .outOfSync: Palette.Status.conflict.ink.color
        case .conflict: Palette.Status.deleted.ink.color
        }
    }

    private var help: String {
        var lines = ["path: \(submodule.path)", "url: \(submodule.url ?? "unknown")", "commit: \(submodule.commit)"]
        switch submodule.state {
        case .current: break
        case .notInitialized: lines.append("Not cloned yet. Update Submodules runs git submodule update --init --recursive.")
        case .outOfSync: lines.append("The submodule is checked out at another commit than the one recorded in this repository.")
        case .conflict: lines.append("Merge conflict on the submodule commit.")
        }
        return lines.joined(separator: "\n")
    }
}

struct AddSubmoduleSheet: View {
    let onAdd: (SubmoduleForm) -> Void
    @State private var form = SubmoduleForm()

    var body: some View {
        RemoteDialog(
            title: "Add Submodule",
            glyph: "shippingbox",
            kind: .form,
            confirmTitle: "Add Submodule",
            identifier: "submoduleSheet",
            canConfirm: form.canAdd,
            command: DialogCommands.addSubmodule(url: form.url, path: form.path),
            onConfirm: { onAdd(form) }
        ) {
            DialogLabeledRow("URL") {
                DialogTextField(placeholder: "https://github.com/user/library.git", text: $form.url, identifier: "submoduleSheet.url")
            }
            DialogLabeledRow("Path") {
                DialogTextField(placeholder: "vendor/library", text: $form.path, identifier: "submoduleSheet.path")
            }
        }
    }
}

struct SubmoduleUpdateSheet: View {
    let viewModel: RepositoryViewModel
    @Environment(\.dismiss) private var dismiss

    private var update: SubmoduleUpdate { viewModel.submoduleUpdate }

    var body: some View {
        DialogScaffold(
            kind: .notice,
            glyph: "arrow.triangle.2.circlepath",
            title: "Update Submodules",
            message: "Clones missing submodules, then checks each one out at the commit this repository records for it.",
            width: Metrics.Sheet.wideWidth
        ) {
            if update.isRunning {
                DialogProgressBar(fraction: update.progress.percent.map { Double($0) / 100 })
            }
            CommandStrip(command: DialogCommands.updateSubmodules, note: update.isRunning ? "Updating…" : "Done", noteIdentifier: "submoduleUpdate.status")
            if !update.progress.lines.isEmpty {
                LogLinesList(lines: update.progress.lines)
                    .frame(height: Metrics.Sheet.logHeight)
                    .background(Palette.Surface.well.color)
                    .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous))
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("submoduleUpdate.progress")
            }
        } buttons: {
            DialogConfirmButton(title: "Close", identifier: "submoduleUpdate.close") { dismiss() }
                .disabled(update.isRunning)
        }
        .interactiveDismissDisabled(update.isRunning)
        .task { await viewModel.updateSubmodules() }
    }
}

struct SubmodulePointerView: View {
    let summary: String

    var body: some View {
        VStack(spacing: Metrics.Spacing.m) {
            Image(systemName: "shippingbox")
                .font(.system(size: Metrics.Sheet.dialogIconSize - Metrics.Spacing.l))
                .foregroundStyle(Palette.Text.secondary.color)
            Text(summary)
                .font(Metrics.Font.monoBody)
                .foregroundStyle(Palette.Text.primary.color)
                .textSelection(.enabled)
                .accessibilityIdentifier("detail.submodulePointer")
            Text("A submodule is stored as a pointer to one commit of another repository. This change moves that pointer; commit it to record the new commit.")
                .font(Metrics.Font.body)
                .foregroundStyle(Palette.Text.secondary.color)
                .multilineTextAlignment(.center)
                .frame(maxWidth: Metrics.Sheet.alertWidth)
        }
        .padding(Metrics.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
