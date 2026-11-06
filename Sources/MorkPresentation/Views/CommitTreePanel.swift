import MorkDomain
import SwiftUI

struct CommitTreePanel: View {
    let session: CommitTreeViewModel
    var editorName: String?

    var body: some View {
        CommitTreeBrowser(session: session, editorName: editorName)
            .overlay { CommitTreeRootState(root: session.root, hasRows: !session.rows.isEmpty) }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("commitTree.panel")
            .modifier(CommitTreeAlerts(session: session))
    }
}

private struct CommitTreeBrowser: View {
    let session: CommitTreeViewModel
    let editorName: String?

    var body: some View {
        PaneSplit(
            .horizontal,
            key: PaneSplitKey.changesFilesWidth,
            defaultSize: Metrics.CommitDetails.filesPaneIdealWidth,
            range: Metrics.CommitDetails.filesPaneMinimumWidth...Metrics.CommitDetails.filesPaneMaximumWidth,
            mainMinimum: Metrics.CommitDetails.diffMinimumWidth,
            identifier: "commitTree.resize"
        ) {
            VStack(spacing: 0) {
                CommitTreeFilterRow(session: session)
                Hairline()
                CommitTreeList(session: session, editorName: editorName)
            }
        } main: {
            CommitTreeContent(session: session)
        }
    }
}

private struct CommitTreeFilterRow: View {
    @Bindable var session: CommitTreeViewModel

    var body: some View {
        FileFilterRow(text: $session.filter, identifier: "commitTree.filter") {
            EmptyView()
        }
    }
}

private struct CommitTreeRootState: View {
    let root: Loadable<[TreeEntry]>
    let hasRows: Bool

    var body: some View {
        switch root {
        case let .failed(message):
            EmptyStateView("Could Not List Files", systemImage: "exclamationmark.triangle", message: message)
                .background(Palette.Surface.window.color)
        case let .loaded(entries) where entries.isEmpty:
            EmptyStateView("No Files in This Commit", systemImage: "folder")
                .background(Palette.Surface.window.color)
        case .idle, .loading:
            if !hasRows {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Palette.Surface.window.color)
            }
        case .loaded:
            EmptyView()
        }
    }
}

private struct CommitTreeAlerts: ViewModifier {
    @Bindable var session: CommitTreeViewModel

    func body(content: Content) -> some View {
        content
            .errorAlert($session.errorMessage)
            .morkConfirmation(item: $session.notice) { notice in
                .notice(title: notice.title, message: notice.message, identifier: "commitTree.notice.ok")
            }
    }
}

private struct CommitTreeList: View {
    let session: CommitTreeViewModel
    let editorName: String?

    var body: some View {
        let selectedPath = session.selectedPath
        let firstID = session.rows.first?.id
        List(selection: Binding(get: { session.selectedPath }, set: { session.select(path: $0) })) {
            ForEach(session.rows) { row in
                CommitTreeRowView(row: row) {
                    if let entry = row.entry { session.toggle(entry) }
                }
                .frame(height: Metrics.Row.list)
                .background { if row.id == selectedPath || row.id == firstID { InkSelectionTableStyle() } }
                .listRowBackground(row.id == selectedPath ? Palette.Accent.tint.color : nil)
                .listRowInsets(Metrics.listRowInsets)
                .listRowSeparator(.hidden)
                .onHover { inside in session.hover(path: inside ? row.id : nil) }
                .tag(row.id)
            }
        }
        .listStyle(.inset)
        .environment(\.defaultMinListRowHeight, Metrics.Row.list)
        .contextMenu(forSelectionType: String.self) { ids in
            if ids.count == 1, let id = ids.first, let entry = session.rows.first(where: { $0.id == id })?.entry, entry.hasContent {
                Button("Save As…") {
                    session.select(path: id)
                    Task { await session.saveSelected() }
                }
                .accessibilityIdentifier("commitTree.saveAs")
                Button(IntegrationFileMenu.editorTitle(editorName, line: nil)) {
                    session.select(path: id)
                    Task { await session.openSelectedInEditor() }
                }
                .accessibilityIdentifier("commitTree.openInEditor")
            }
        } primaryAction: { ids in
            guard ids.count == 1, let id = ids.first, let row = session.rows.first(where: { $0.id == id }), let entry = row.entry else { return }
            if entry.isDirectory { session.toggle(entry) } else { Task { await session.openSelectedInEditor() } }
        }
        .accessibilityIdentifier("commitTree.list")
    }
}

private struct CommitTreeRowView: View {
    let row: TreeRow
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: Metrics.Spacing.xs) {
            Color.clear.frame(width: CGFloat(row.depth) * Metrics.Indent.level)
            switch row.content {
            case let .entry(entry):
                if entry.isDirectory {
                    Button(action: toggle) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: Metrics.Icon.disclosure, weight: .semibold))
                            .rotationEffect(.degrees(row.isExpanded ? 90 : 0))
                            .frame(width: Metrics.Indent.disclosure)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.Text.secondary.color)
                    .accessibilityLabel(row.isExpanded ? "Collapse" : "Expand")
                    .accessibilityIdentifier("commitTree.toggle.\(entry.path)")
                    Image(systemName: "folder")
                        .foregroundStyle(Palette.Text.secondary.color)
                        .frame(width: Metrics.Icon.column)
                } else {
                    Color.clear.frame(width: Metrics.Indent.disclosure)
                    TreeEntryIcon(entry: entry)
                }
                Text(entry.name)
                    .foregroundStyle(Palette.Text.primary.color)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: Metrics.Spacing.xs)
            case .loading:
                ProgressView()
                    .controlSize(.small)
                Text("Loading…").foregroundStyle(Palette.Text.secondary.color)
            case let .failed(message):
                Image(systemName: "exclamationmark.triangle").foregroundStyle(Palette.Status.conflict.ink.color)
                Text(message).foregroundStyle(Palette.Text.secondary.color).lineLimit(1)
            case .empty:
                Text("Empty folder").foregroundStyle(Palette.Text.secondary.color)
            }
        }
        .font(Metrics.Font.title)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("commitTree.row.\(row.id)")
        .accessibilityValue(row.isExpanded ? "expanded" : "")
    }
}

private struct TreeEntryIcon: View {
    let entry: TreeEntry

    var body: some View {
        switch entry.kind {
        case .symlink:
            Image(systemName: "arrow.uturn.right.square")
                .foregroundStyle(Palette.Text.secondary.color)
                .frame(width: Metrics.Icon.column)
        case .submodule:
            Image(systemName: "shippingbox")
                .foregroundStyle(Palette.Text.secondary.color)
                .frame(width: Metrics.Icon.column)
        default:
            FileIcon(path: entry.path)
        }
    }
}

private struct CommitTreeContent: View {
    let session: CommitTreeViewModel

    var body: some View {
        VStack(spacing: 0) {
            CommitTreeFileHeader(path: session.displayedPath)
            Hairline()
            DiffText(document: session.document ?? .empty)
                .accessibilityIdentifier("commitTree.text")
                .overlay { CommitTreeViewerOverlay(session: session) }
                .overlay(alignment: .topTrailing) {
                    if session.showsLoadingIndicator {
                        ProgressView()
                            .controlSize(.small)
                            .padding(Metrics.Spacing.s)
                            .accessibilityIdentifier("commitTree.loading")
                    }
                }
        }
    }
}

private struct CommitTreeFileHeader: View {
    let path: String?

    var body: some View {
        HStack(spacing: Metrics.Spacing.xs) {
            if let path {
                FileIcon(path: path)
                PathLabel(path: path, font: .systemFont(ofSize: Metrics.FontSize.body))
                    .layoutPriority(-1)
            }
        }
        .padding(.horizontal, Metrics.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Metrics.CommitDetails.diffHeaderHeight)
        .background(Palette.Surface.window.color)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("commitTree.fileHeader")
    }
}

private struct CommitTreeViewerOverlay: View {
    let session: CommitTreeViewModel

    var body: some View {
        if let entry = session.selectedEntry, !entry.hasContent {
            EmptyStateView(entry.kind == .submodule ? "Submodule at \(String(entry.object.prefix(7)))" : entry.name, systemImage: entry.kind == .submodule ? "shippingbox" : "folder")
                .background(Palette.Surface.window.color)
        } else if session.selectedPath == nil, session.displayedPath == nil {
            EmptyStateView("Select a File", systemImage: "doc.text.magnifyingglass", message: "Each file shows exactly as it was in this commit.")
                .background(Palette.Surface.window.color)
        } else {
            switch session.content {
            case let .failed(message):
                EmptyStateView("Could Not Read File", systemImage: "exclamationmark.triangle", message: message)
                    .background(Palette.Surface.window.color)
            case let .loaded(content):
                FileRevisionPlaceholder(content: content, isEmpty: session.document?.lines.isEmpty ?? true) { Task { await session.saveSelected() } }
            case .idle, .loading:
                EmptyView()
            }
        }
    }
}

private struct FileRevisionPlaceholder: View {
    let content: FileRevisionContent
    let isEmpty: Bool
    let save: () -> Void

    var body: some View {
        switch content {
        case .text:
            if isEmpty {
                EmptyStateView("Empty File", systemImage: "doc")
                    .background(Palette.Surface.window.color)
            }
        case let .binary(count):
            placeholder("Binary File", systemImage: "doc.zipper", message: "\(Self.size(count)). Binary content is not shown as text.")
                .accessibilityIdentifier("commitTree.binary")
        case let .tooLarge(count):
            placeholder("Large File", systemImage: "doc.text.magnifyingglass", message: "\(Self.size(count)) is over the \(Self.size(FileRevisionContent.textLimit)) preview limit.")
                .accessibilityIdentifier("commitTree.large")
        }
    }

    private func placeholder(_ title: String, systemImage: String, message: String) -> some View {
        EmptyStateView(title, systemImage: systemImage, message: message) {
            Button("Save As…", action: save)
                .buttonStyle(.morkSecondary)
        }
        .background(Palette.Surface.window.color)
    }

    static func size(_ count: Int) -> String {
        Int64(count).formatted(.byteCount(style: .file))
    }
}
