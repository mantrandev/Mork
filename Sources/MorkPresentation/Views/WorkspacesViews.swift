import MorkDomain
import SwiftUI

indirect enum WorkspaceMenuNode: Equatable {
    case workspace(title: String, Workspace)
    case folder(title: String, [WorkspaceMenuNode])
}

enum WorkspaceMenuTree {
    static func build(_ workspaces: [Workspace]) -> [WorkspaceMenuNode] {
        var nodes: [WorkspaceMenuNode] = []
        for workspace in workspaces {
            let parts = workspace.name.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            guard let leaf = parts.last else { continue }
            insert(workspace, title: leaf, path: Array(parts.dropLast()), into: &nodes)
        }
        return nodes
    }

    private static func insert(_ workspace: Workspace, title: String, path: [String], into nodes: inout [WorkspaceMenuNode]) {
        guard let folder = path.first else {
            nodes.append(.workspace(title: title, workspace))
            return
        }
        let index = nodes.firstIndex { node in
            if case let .folder(name, _) = node { return name == folder }
            return false
        }
        var children: [WorkspaceMenuNode] = []
        if let index, case let .folder(_, existing) = nodes[index] { children = existing }
        insert(workspace, title: title, path: Array(path.dropFirst()), into: &children)
        if let index {
            nodes[index] = .folder(title: folder, children)
        } else {
            nodes.append(.folder(title: folder, children))
        }
    }
}

struct WorkspacesButton: View {
    let app: AppViewModel
    @State private var anchor = MenuAnchor()

    var body: some View {
        ToolbarCaptionButton(title: app.currentWorkspace.name, systemImage: "rectangle.on.rectangle", captionMaxWidth: Metrics.Toolbar.captionMaxWidth) {
            anchor.popUp(entries)
        }
        .background(MenuAnchorView(anchor: anchor))
        .help("Workspace: \(app.currentWorkspace.name)")
        .accessibilityLabel("Workspace \(app.currentWorkspace.name)")
        .accessibilityIdentifier("toolbar.workspaces")
    }

    private var entries: [MenuEntry] {
        [MenuEntry(title: "Workspaces:", isEnabled: false) {}, .separator]
            + WorkspaceMenuTree.build(app.workspaces).map(entry)
            + [.separator, MenuEntry(title: "Configure…", identifier: "workspaces.configure") { app.isWorkspaceSheetPresented = true }]
    }

    private func entry(_ node: WorkspaceMenuNode) -> MenuEntry {
        switch node {
        case let .workspace(title, workspace):
            MenuEntry(title: title, isChecked: workspace.id == app.currentWorkspace.id, identifier: "workspaces.item.\(workspace.name)") {
                Task { await app.switchWorkspace(to: workspace.id) }
            }
        case let .folder(title, children):
            MenuEntry(title: title, systemImage: "folder", identifier: "workspaces.folder.\(title)", children: children.map(entry)) {}
        }
    }
}

struct WorkspacesMenu: View {
    let app: AppViewModel

    var body: some View {
        Menu("Workspaces") {
            WorkspaceMenuItems(app: app, nodes: WorkspaceMenuTree.build(app.workspaces))
            Divider()
            Button("Configure Workspaces…") { app.isWorkspaceSheetPresented = true }
        }
    }
}

private struct WorkspaceMenuItems: View {
    let app: AppViewModel
    let nodes: [WorkspaceMenuNode]

    var body: some View {
        ForEach(Array(nodes.enumerated()), id: \.offset) { _, node in
            switch node {
            case let .workspace(title, workspace):
                Toggle(title, isOn: Binding(
                    get: { workspace.id == app.currentWorkspace.id },
                    set: { isOn in if isOn { Task { await app.switchWorkspace(to: workspace.id) } } }
                ))
            case let .folder(title, children):
                Menu(title) { WorkspaceMenuItems(app: app, nodes: children) }
            }
        }
    }
}

struct WorkspacesSheet: View {
    let app: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selection: UUID?
    @State private var editing: UUID?

    var body: some View {
        DialogScaffold(
            kind: .form,
            glyph: "rectangle.on.rectangle",
            title: "Workspaces",
            width: Metrics.Sheet.alertWidth
        ) {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach(app.workspaces) { workspace in
                        WorkspaceNameRow(app: app, workspace: workspace, isEditing: editing == workspace.id) { editing = $0 ? workspace.id : nil }
                            .tag(workspace.id)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: Metrics.Spacing.s, bottom: 0, trailing: Metrics.Spacing.s))
                    }
                }
                .listStyle(.plain)
                .environment(\.defaultMinListRowHeight, Metrics.Row.list)
                .scrollContentBackground(.hidden)
                .accessibilityIdentifier("workspaces.list")
                Hairline()
                HStack(spacing: 0) {
                    Button {
                        let added = app.addWorkspace()
                        selection = added.id
                        editing = added.id
                    } label: {
                        Image(systemName: "plus").frame(width: Metrics.HitTarget.icon, height: Metrics.HitTarget.inline)
                    }
                    .help("Add a workspace")
                    .accessibilityIdentifier("workspaces.add")
                    Button {
                        guard let selection else { return }
                        Task { await app.deleteWorkspace(selection) }
                        self.selection = nil
                        editing = nil
                    } label: {
                        Image(systemName: "minus").frame(width: Metrics.HitTarget.icon, height: Metrics.HitTarget.inline)
                    }
                    .disabled(selection == nil || app.workspaces.count < 2)
                    .help("Delete the selected workspace")
                    .accessibilityIdentifier("workspaces.delete")
                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, Metrics.Spacing.xxs)
            }
            .background(Palette.Surface.window.color)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous).strokeBorder(Palette.Surface.borderStrong.color, lineWidth: Metrics.Line.hairline))
            .frame(height: Metrics.Sheet.workspacesListHeight)
        } buttons: {
            DialogCancelButton(title: "Close", identifier: "workspaces.done") { dismiss() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workspaces.sheet")
    }
}

private struct WorkspaceNameRow: View {
    let app: AppViewModel
    let workspace: Workspace
    let isEditing: Bool
    let setEditing: (Bool) -> Void
    @State private var name = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            if isEditing {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .onSubmit(commit)
                    .onExitCommand { setEditing(false) }
                    .onChange(of: isFocused) { _, focused in if !focused { commit() } }
                    .onAppear {
                        name = workspace.name
                        isFocused = true
                    }
                    .accessibilityIdentifier("workspaces.field.\(workspace.name)")
            } else {
                Text(workspace.name)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .simultaneousGesture(TapGesture(count: 2).onEnded { setEditing(true) })
                    .accessibilityIdentifier("workspaces.name.\(workspace.name)")
            }
        }
        .frame(height: Metrics.Row.list)
    }

    private func commit() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != workspace.name { app.renameWorkspace(workspace.id, to: trimmed) }
        setEditing(false)
    }
}
