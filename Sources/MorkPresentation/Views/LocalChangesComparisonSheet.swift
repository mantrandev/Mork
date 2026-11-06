import MorkDomain
import SwiftUI

struct LocalChangesComparisonSheet: View {
    let session: LocalChangesComparisonViewModel
    let close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: Metrics.Sheet.headerGap) {
                DialogGlyphTile(kind: .notice, glyph: "arrow.left.arrow.right")
                VStack(alignment: .leading, spacing: Metrics.Spacing.xs) {
                    Text(session.title)
                        .font(Metrics.Font.heading)
                        .foregroundStyle(Palette.Text.primary.color)
                        .lineLimit(1)
                        .accessibilityIdentifier("compareLocal.title")
                    CommandStrip(command: session.command, note: "read only", identifier: "compareLocal.command")
                        .help(session.lesson)
                }
                Spacer(minLength: Metrics.Spacing.s)
                Button("Refresh", systemImage: "arrow.clockwise", action: session.refresh)
                    .buttonStyle(.morkSecondary)
                    .accessibilityIdentifier("compareLocal.refresh")
                Button("Done", action: close)
                    .buttonStyle(.morkPrimary)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("compareLocal.close")
            }
            .padding(Metrics.Spacing.m)
            .dialogSurface()
            Hairline()
            LocalChangesComparisonContent(session: session)
        }
        .frame(minWidth: Metrics.Inspector.minimumWidth, idealWidth: Metrics.Inspector.idealWidth, minHeight: Metrics.Inspector.minimumHeight, idealHeight: Metrics.Inspector.idealHeight)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("compareLocal.sheet")
    }
}

private struct LocalChangesComparisonContent: View {
    let session: LocalChangesComparisonViewModel

    var body: some View {
        PaneSplit(
            .horizontal,
            key: PaneSplitKey.inspectorListWidth,
            defaultSize: Metrics.Inspector.listIdealWidth,
            range: Metrics.Inspector.listMinimumWidth...Metrics.Inspector.listMaximumWidth,
            mainMinimum: Metrics.Inspector.contentMinimumWidth,
            identifier: "compareLocal.resize"
        ) {
            LocalChangesFileList(session: session)
        } main: {
            LocalChangesDiffPane(session: session)
        }
        .overlay { LocalChangesComparisonState(files: session.files, shortHash: session.commit.shortHash) }
    }
}

private struct LocalChangesComparisonState: View {
    let files: Loadable<LocalChangesComparison>
    let shortHash: String

    var body: some View {
        switch files {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.Surface.window.color)
        case let .failed(message):
            EmptyStateView("Could Not Compare", systemImage: "exclamationmark.triangle", message: message)
                .background(Palette.Surface.window.color)
                .accessibilityIdentifier("compareLocal.failed")
        case let .loaded(comparison) where comparison.isEmpty:
            EmptyStateView("No Differences", systemImage: "checkmark.circle", message: "The files on disk match \(shortHash).")
                .background(Palette.Surface.window.color)
                .accessibilityIdentifier("compareLocal.empty")
        case .loaded:
            EmptyView()
        }
    }
}

private struct LocalChangesFileList: View {
    let session: LocalChangesComparisonViewModel

    var body: some View {
        ComparedFileTable(files: session.listedFiles, revision: session.filesRevision, selectedID: session.selectedID, onSelect: session.select)
    }
}

private struct LocalChangesDiffPane: View {
    let session: LocalChangesComparisonViewModel

    var body: some View {
        VStack(spacing: 0) {
            LocalChangesDiffHeader(file: session.displayedFile, command: session.fileCommand)
            Hairline()
            DiffText(document: session.document)
                .accessibilityIdentifier("compareLocal.diff")
                .overlay { LocalChangesDiffOverlay(session: session) }
                .overlay(alignment: .topTrailing) {
                    if session.showsLoadingIndicator {
                        ProgressView()
                            .controlSize(.small)
                            .padding(Metrics.Spacing.s)
                            .accessibilityIdentifier("compareLocal.loading")
                    }
                }
        }
    }
}

struct LocalChangesDiffHeader: View {
    let file: ComparedFile?
    let command: String?

    var body: some View {
        HStack(spacing: Metrics.ChangeRow.gap) {
            if let file {
                FileIcon(path: file.path)
                Text(FilePathParts(file.path).name)
                    .font(Metrics.Font.body.weight(.semibold))
                    .foregroundStyle(Palette.Text.primary.color)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: Metrics.Spacing.s)
            if let command {
                Text(command)
                    .font(Metrics.Font.monoCaption)
                    .foregroundStyle(Palette.Text.secondary.color)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityIdentifier("compareLocal.fileCommand")
            }
        }
        .padding(.horizontal, Metrics.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Metrics.CommitDetails.diffHeaderHeight)
        .background(Palette.Surface.sidebar.color)
    }
}

private struct LocalChangesDiffOverlay: View {
    let session: LocalChangesComparisonViewModel

    var body: some View {
        if let message = session.diffError {
            EmptyStateView("Could Not Load Diff", systemImage: "exclamationmark.triangle", message: message)
                .background(Palette.Surface.window.color)
        } else if session.displayedFile == nil, session.selectedID == nil {
            EmptyStateView("Select a File", systemImage: "doc.text.magnifyingglass", message: "Each file shows how the files on disk differ from this commit.")
                .background(Palette.Surface.window.color)
        }
    }
}
