import MorkDomain
import SwiftUI

struct FileInspectionMenu: View {
    let viewModel: RepositoryViewModel
    let path: String
    var commit: Commit?
    var isTracked = true

    var body: some View {
        Button("Show File History") { viewModel.showFileHistory(path: path) }
            .disabled(!isTracked)
            .accessibilityIdentifier("file.history")
        Button("Blame") { viewModel.showBlame(path: path, at: commit) }
            .disabled(!isTracked)
            .accessibilityIdentifier("file.blame")
    }
}

struct FileInspectorSheet: View {
    let viewModel: RepositoryViewModel
    let inspector: FileInspector

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Metrics.Sheet.rowSpacing) {
                HStack(alignment: .top, spacing: Metrics.Spacing.s) {
                    DialogHeader(kind: .notice, glyph: systemImage, title: title, message: lesson)
                    if case let .blame(path, _) = inspector {
                        Button(IntegrationFileMenu.editorTitle(viewModel.editorName, line: nil)) { Task { await viewModel.openInEditor(path: path) } }
                            .buttonStyle(.morkSecondary)
                            .accessibilityIdentifier("fileInspector.openInEditor")
                    }
                    Button("Done") { viewModel.closeFileInspector() }
                        .buttonStyle(.morkSecondary)
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("fileInspector.close")
                }
                CommandStrip(command: command, identifier: "fileInspector.command")
            }
            .padding(Metrics.Sheet.padding)
            .background(Palette.Surface.dialog.color)
            Hairline()
            switch inspector {
            case .history: FileHistoryView(viewModel: viewModel)
            case .blame: BlameView(viewModel: viewModel)
            case .lineHistory: LineHistoryView(viewModel: viewModel)
            }
        }
        .frame(minWidth: Metrics.Inspector.minimumWidth, idealWidth: Metrics.Inspector.idealWidth, minHeight: Metrics.Inspector.minimumHeight, idealHeight: Metrics.Inspector.idealHeight)
    }

    private var title: String {
        switch inspector {
        case let .history(path): "History of \(path)"
        case let .blame(path, commit): "Blame \(path)" + (commit.map { " at \($0.shortHash)" } ?? "")
        case let .lineHistory(request): "History of \(request.lineDescription) in \(request.path)"
        }
    }

    private var systemImage: String {
        switch inspector {
        case .history: "clock.arrow.circlepath"
        case .blame: "person.text.rectangle"
        case .lineHistory: "text.line.first.and.arrowtriangle.forward"
        }
    }

    private var command: String {
        switch inspector {
        case let .history(path): DialogCommands.fileHistory(path)
        case let .blame(path, commit): DialogCommands.blame(path, at: commit)
        case let .lineHistory(request): DialogCommands.lineHistory(request)
        }
    }

    private var lesson: String {
        switch inspector {
        case .history: "--follow keeps the history going across renames. Each commit shows only this file's diff."
        case .blame: "Every line shows the commit that last changed it. Click a commit on the left to show it in history."
        case .lineHistory: "-L traces only these lines back through history, following them when they move or the file is renamed. Each commit shows the diff of just that range."
        }
    }
}

struct FileHistoryView: View {
    let viewModel: RepositoryViewModel

    var body: some View {
        switch viewModel.inspection.history {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .failed(message):
            EmptyStateView("Could Not Load File History", systemImage: "exclamationmark.triangle", message: message)
        case let .loaded(entries) where entries.isEmpty:
            EmptyStateView("No Commits Touch This File", systemImage: "doc")
                .accessibilityIdentifier("fileHistory.empty")
        case let .loaded(entries):
            PaneSplit(
                .horizontal,
                key: PaneSplitKey.inspectorListWidth,
                defaultSize: Metrics.Inspector.listIdealWidth,
                range: Metrics.Inspector.listMinimumWidth...Metrics.Inspector.listMaximumWidth,
                mainMinimum: Metrics.Inspector.contentMinimumWidth,
                identifier: "fileHistory.resize"
            ) {
                List(selection: Binding(get: { viewModel.inspection.selectedEntry?.id }, set: { id in
                    if let entry = entries.first(where: { $0.id == id }) { viewModel.select(entry) }
                })) {
                    ForEach(entries) { entry in
                        FileHistoryRow(entry: entry)
                            .tag(entry.id)
                    }
                }
                .accessibilityIdentifier("fileHistory.list")
            } main: {
                diff
            }
            .accessibilityIdentifier("fileHistory.view")
        }
    }

    private var diff: some View {
        FileHistoryDiff(diff: viewModel.inspection.diff)
    }
}

struct FileHistoryDiff: View {
    let diff: RepositoryViewModel.Detail

    var body: some View {
        switch diff {
        case .empty:
            EmptyStateView("Select a Commit", systemImage: "doc.text.magnifyingglass")
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .failed(message):
            EmptyStateView("Could Not Load Diff", systemImage: "exclamationmark.triangle", message: message)
        case let .loaded(text):
            DiffText(document: DiffDocument(lines: DiffLine.parse(text), tabWidth: DiffMetrics.standard.tabWidth))
        }
    }
}

struct LineHistoryView: View {
    let viewModel: RepositoryViewModel

    var body: some View {
        switch viewModel.inspection.lineHistory {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .failed(message):
            EmptyStateView("Could Not Load Line History", systemImage: "exclamationmark.triangle", message: message)
                .accessibilityIdentifier("lineHistory.failed")
        case let .loaded(entries) where entries.isEmpty:
            EmptyStateView("No Commits Touch These Lines", systemImage: "doc")
                .accessibilityIdentifier("lineHistory.empty")
        case let .loaded(entries):
            PaneSplit(
                .horizontal,
                key: PaneSplitKey.inspectorListWidth,
                defaultSize: Metrics.Inspector.listIdealWidth,
                range: Metrics.Inspector.listMinimumWidth...Metrics.Inspector.listMaximumWidth,
                mainMinimum: Metrics.Inspector.contentMinimumWidth,
                identifier: "lineHistory.resize"
            ) {
                List(selection: Binding(get: { viewModel.inspection.selectedLineEntry?.id }, set: { id in
                    if let entry = entries.first(where: { $0.id == id }) { viewModel.select(entry) }
                })) {
                    ForEach(entries) { entry in
                        LineHistoryRow(commit: entry.commit)
                            .tag(entry.id)
                    }
                }
                .accessibilityIdentifier("lineHistory.list")
            } main: {
                FileHistoryDiff(diff: viewModel.inspection.diff)
            }
            .accessibilityIdentifier("lineHistory.view")
        }
    }
}

private struct LineHistoryRow: View {
    let commit: Commit

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.xxs) {
            Text(commit.subject)
                .font(Metrics.Font.body)
                .foregroundStyle(Palette.Text.primary.color)
                .lineLimit(1)
            HStack(spacing: Metrics.Spacing.xs + Metrics.Spacing.xxs) {
                Text(commit.shortHash)
                    .font(Metrics.Font.monoCaption)
                Text(commit.author)
                Text(commit.date, format: .relative(presentation: .numeric))
                    .monospacedDigit()
            }
            .font(Metrics.Font.caption)
            .foregroundStyle(Palette.Text.secondary.color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("lineHistory.commit.\(commit.subject)")
    }
}

private struct FileHistoryRow: View {
    let entry: FileHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.xxs) {
            Text(entry.commit.subject)
                .font(Metrics.Font.body)
                .foregroundStyle(Palette.Text.primary.color)
                .lineLimit(1)
            HStack(spacing: Metrics.Spacing.xs + Metrics.Spacing.xxs) {
                Text(entry.commit.shortHash)
                    .font(Metrics.Font.monoCaption)
                Text(entry.commit.author)
                Text(entry.commit.date, format: .relative(presentation: .numeric))
                    .monospacedDigit()
                if let original = entry.file.originalPath {
                    Text("renamed from \(original)")
                        .foregroundStyle(Palette.Status.renamed.ink.color)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .font(Metrics.Font.caption)
            .foregroundStyle(Palette.Text.secondary.color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("fileHistory.commit.\(entry.commit.subject)")
    }
}

struct BlameView: View {
    static let gutterWidth = Metrics.Blame.gutterWidth
    static let rowHeight = Metrics.Blame.rowHeight
    static let numberWidth = Metrics.Blame.numberWidth
    static let characterWidth = ("0" as NSString).size(withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: Metrics.FontSize.body, weight: .regular)]).width

    let viewModel: RepositoryViewModel

    var body: some View {
        switch viewModel.inspection.blame {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .failed(message):
            EmptyStateView("Could Not Blame File", systemImage: "exclamationmark.triangle", message: message)
                .accessibilityIdentifier("blame.failed")
        case let .loaded(blocks) where blocks.isEmpty:
            EmptyStateView("Empty File", systemImage: "doc")
        case .loaded:
            GeometryReader { proxy in
                let width = max(proxy.size.width, BlameView.gutterWidth + Self.numberWidth + Metrics.Spacing.xl + CGFloat(viewModel.inspection.blameColumns) * Self.characterWidth)
                ScrollView(.horizontal) {
                    List(viewModel.inspection.blameRows) { row in
                        BlameLineRow(row: row, editor: viewModel.editorName) { Task { await viewModel.reveal(row.commit) } } openLine: { line in
                            if case let .blame(path, _) = viewModel.fileInspector { Task { await viewModel.openInEditor(path: path, line: line) } }
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .environment(\.defaultMinListRowHeight, Self.rowHeight)
                    .frame(width: width, height: proxy.size.height)
                }
            }
            .accessibilityIdentifier("blame.view")
        }
    }
}

private struct BlameLineRow: View {
    let row: BlameRow
    let editor: String?
    let reveal: () -> Void
    let openLine: (Int) -> Void

    private var commit: BlameCommit { row.commit }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            gutter
                .frame(width: BlameView.gutterWidth, alignment: .leading)
                .padding(.horizontal, Metrics.Spacing.xs + Metrics.Spacing.xxs)
            Hairline(isVertical: true)
            HStack(spacing: Metrics.Spacing.s) {
                Text("\(row.line.number)")
                    .foregroundStyle(Palette.Text.secondary.color)
                    .frame(width: BlameView.numberWidth, alignment: .trailing)
                Text(row.line.content.isEmpty ? " " : row.line.content)
                    .foregroundStyle(Palette.Text.primary.color)
                    .lineLimit(1)
                    .fixedSize()
                    .textSelection(.enabled)
            }
            .font(Metrics.Font.monoBody)
            .padding(.leading, Metrics.Spacing.xs + Metrics.Spacing.xxs)
            .contextMenu {
                Button(IntegrationFileMenu.editorTitle(editor, line: row.line.number)) { openLine(row.line.number) }
                    .accessibilityIdentifier("blame.line.openInEditor")
            }
            .accessibilityIdentifier("blame.line.\(row.line.number)")
        }
        .frame(maxWidth: .infinity, minHeight: BlameView.rowHeight, maxHeight: BlameView.rowHeight, alignment: .leading)
        .background(row.isShaded ? Palette.Surface.rowAlt.color : Color.clear)
    }

    @ViewBuilder
    private var gutter: some View {
        switch row.gutter {
        case .commit:
            Button(action: reveal) {
                HStack(spacing: Metrics.Spacing.xs + Metrics.Spacing.xxs) {
                    Text(commit.isUncommitted ? "uncommitted" : (commit.isBoundary ? "^" : "") + commit.shortHash)
                        .font(Metrics.Font.monoCaption)
                        .foregroundStyle(commit.isUncommitted ? Palette.Status.conflict.ink.color : Palette.Accent.text.color)
                    Text(commit.author)
                        .foregroundStyle(Palette.Text.primary.color)
                        .lineLimit(1)
                    Spacer(minLength: Metrics.Spacing.xs)
                    Text(commit.date, format: .relative(presentation: .numeric))
                        .monospacedDigit()
                        .foregroundStyle(Palette.Text.secondary.color)
                        .lineLimit(1)
                }
                .font(Metrics.Font.caption)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(commit.isUncommitted)
            .help(commit.isUncommitted ? "Not committed yet" : "\(commit.summary)\nClick to show \(commit.shortHash) in history")
            .accessibilityIdentifier("blame.gutter.\(row.block)")
        case .summary:
            Text(commit.summary)
                .font(Metrics.Font.caption)
                .foregroundStyle(Palette.Text.secondary.color)
                .lineLimit(1)
        case .none:
            Color.clear
        }
    }
}
