import MorkDomain
import SwiftUI

struct MultiCommitDetailsView: View {
    static let tabs: [CommitDetailsTab] = [.commit, .changes]

    let viewModel: RepositoryViewModel
    let layout: CommitDetailsLayout
    let toggleFilesPlacement: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            CommitDetailsTabBar(selection: tab, tabs: Self.tabs, placement: layout.filesPlacement, toggleFilesPlacement: toggleFilesPlacement)
            Hairline()
            MultiCommitHeader(count: viewModel.multiSelectionRows.count, command: viewModel.commitDetailsTab == .changes ? rangeCommand : nil)
            Hairline()
            if viewModel.commitDetailsTab == .changes {
                MultiCommitChanges(viewModel: viewModel, placement: layout.filesPlacement)
            } else {
                MultiCommitList(rows: viewModel.multiSelectionRows)
            }
        }
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("multiCommit")
    }

    private var tab: Binding<CommitDetailsTab> {
        Binding(get: { viewModel.commitDetailsTab == .changes ? .changes : .commit }, set: { viewModel.commitDetailsTab = $0 })
    }

    private var rangeCommand: String? {
        viewModel.selectedCommitRange.map { (["git"] + $0.diffArguments(abbreviated: true)).joined(separator: " ") }
    }
}

private struct MultiCommitHeader: View {
    let count: Int
    let command: String?

    var body: some View {
        HStack(spacing: Metrics.Spacing.s) {
            Text("\(count) commits selected")
                .font(Metrics.Font.title.weight(.semibold))
                .foregroundStyle(Palette.Text.primary.color)
                .accessibilityIdentifier("multiCommit.title")
            Spacer(minLength: Metrics.Spacing.s)
            if let command {
                Text(command)
                    .font(Metrics.Font.monoCaption)
                    .foregroundStyle(Palette.Text.secondary.color)
                    .truncationMode(.middle)
                    .accessibilityIdentifier("multiCommit.command")
            }
        }
        .lineLimit(1)
        .padding(.horizontal, Metrics.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Metrics.CommitDetails.summaryBarHeight)
    }
}

private struct MultiCommitList: View {
    let rows: [HistoryRowModel]

    var body: some View {
        GeometryReader { geometry in
            let columns = HistoryColumns(width: geometry.size.width - Metrics.Spacing.m * 2)
            List {
                ForEach(rows, id: \.id) { row in
                    MultiCommitRow(row: row, columns: columns)
                        .listRowInsets(EdgeInsets(top: 0, leading: Metrics.Spacing.m, bottom: 0, trailing: Metrics.Spacing.m))
                        .listRowSeparator(.hidden)
                        .listRowBackground(HistoryRowBackground.color(isSelected: false))
                }
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, Metrics.Row.history)
            .accessibilityIdentifier("multiCommit.list")
        }
    }
}

private struct MultiCommitRow: View, Equatable {
    let row: HistoryRowModel
    let columns: HistoryColumns

    private var commit: Commit { row.commit }

    var body: some View {
        HStack(spacing: HistoryColumns.spacing) {
            HStack(spacing: Metrics.Spacing.xs) {
                AuthorAvatarImage(name: commit.author, email: commit.authorEmail, style: .row)
                Text(commit.subject)
                    .foregroundStyle(Palette.Text.primary.color)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            Text(commit.shortHash)
                .font(Metrics.Font.monoCaption)
                .foregroundStyle(Palette.Text.secondary.color)
                .frame(width: columns.hash, alignment: .leading)
            if columns.author > 0 {
                Text(commit.author)
                    .foregroundStyle(Palette.Text.secondary.color)
                    .frame(width: columns.author, alignment: .leading)
            }
            Text(row.date)
                .font(Metrics.Font.caption.monospacedDigit())
                .foregroundStyle(Palette.Text.secondary.color)
                .frame(width: columns.date, alignment: .trailing)
        }
        .font(Metrics.Font.body)
        .lineLimit(1)
        .frame(height: Metrics.Row.history)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("multiCommit.row.\(commit.subject)")
    }
}

private struct MultiCommitChanges: View {
    let viewModel: RepositoryViewModel
    let placement: CommitDetailsLayout.FilesPlacement

    var body: some View {
        if viewModel.multiCommitDiffTarget == .multipleRevisions {
            EmptyStateView(
                "No Combined Diff",
                systemImage: "square.stack.3d.up.slash",
                message: "These commits are not one continuous range, so one diff would mix in changes you did not select. Select a continuous run of commits on one line, for example with a click and a ⇧-click, to see their combined changes."
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("multiCommit.notContiguous")
        } else {
            CommitRangeChangesSplit(session: viewModel.rangeChanges, placement: placement)
        }
    }
}

private struct CommitRangeChangesSplit: View {
    let session: CommitRangeChangesViewModel
    let placement: CommitDetailsLayout.FilesPlacement

    var body: some View {
        Group {
            switch placement {
            case .beside:
                PaneSplit(
                    .horizontal,
                    key: PaneSplitKey.changesFilesWidth,
                    defaultSize: Metrics.CommitDetails.filesPaneIdealWidth,
                    range: Metrics.CommitDetails.filesPaneMinimumWidth...Metrics.CommitDetails.filesPaneMaximumWidth,
                    mainMinimum: Metrics.CommitDetails.diffMinimumWidth,
                    identifier: "multiCommit.resize"
                ) {
                    CommitRangeFileList(session: session)
                } main: {
                    CommitRangeDiffPane(session: session)
                }
            case .above:
                PaneSplit(
                    .vertical,
                    key: PaneSplitKey.changesFilesHeight,
                    defaultSize: Metrics.CommitDetails.filesAboveIdealHeight,
                    range: Metrics.CommitDetails.filesAboveMinimumHeight...Metrics.CommitDetails.filesAboveMaximumHeight,
                    mainMinimum: Metrics.CommitDetails.diffBelowMinimumHeight,
                    identifier: "multiCommit.resize"
                ) {
                    CommitRangeFileList(session: session)
                } main: {
                    CommitRangeDiffPane(session: session)
                }
            }
        }
        .overlay { CommitRangeChangesState(files: session.files) }
    }
}

private struct CommitRangeChangesState: View {
    let files: Loadable<[ComparedFile]>

    var body: some View {
        switch files {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.Surface.window.color)
        case let .failed(message):
            EmptyStateView("Could Not Load the Range", systemImage: "exclamationmark.triangle", message: message)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.Surface.window.color)
        case let .loaded(files) where files.isEmpty:
            EmptyStateView("No File Changes", systemImage: "doc", message: "Together these commits leave every file as it was.")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.Surface.window.color)
                .accessibilityIdentifier("multiCommit.noFiles")
        case .loaded:
            EmptyView()
        }
    }
}

private struct CommitRangeFileList: View {
    let session: CommitRangeChangesViewModel

    var body: some View {
        ComparedFileTable(files: session.listedFiles, revision: session.filesRevision, selectedID: session.selectedID, onSelect: session.select)
            .accessibilityIdentifier("multiCommit.files")
    }
}

private struct CommitRangeDiffPane: View {
    let session: CommitRangeChangesViewModel

    var body: some View {
        VStack(spacing: 0) {
            LocalChangesDiffHeader(file: session.displayedFile, command: session.fileCommand)
            Hairline()
            DiffText(document: session.document)
                .accessibilityIdentifier("multiCommit.diff")
                .overlay {
                    if let message = session.diffError {
                        EmptyStateView("Could Not Load Diff", systemImage: "exclamationmark.triangle", message: message)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Palette.Surface.window.color)
                    }
                }
        }
    }
}
