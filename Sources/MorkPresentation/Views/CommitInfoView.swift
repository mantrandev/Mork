import MorkDomain
import SwiftUI

struct CommitInfoView: View {
    @Bindable var viewModel: RepositoryViewModel
    var layout = CommitDetailsLayout()
    var toggleFilesPlacement: (() -> Void)?

    var body: some View {
        if viewModel.isMultiCommitSelection {
            MultiCommitDetailsView(viewModel: viewModel, layout: layout, toggleFilesPlacement: toggleFilesPlacement)
        } else if let commit = viewModel.selectedCommit {
            VStack(spacing: 0) {
                CommitDetailsTabBar(selection: $viewModel.commitDetailsTab, placement: layout.filesPlacement, toggleFilesPlacement: toggleFilesPlacement)
                Hairline()
                switch viewModel.commitDetailsTab {
                case .commit:
                    CommitOverview(viewModel: viewModel, commit: commit, showsHeader: layout.showsHeader)
                case .changes:
                    CommitSummaryBar(commit: commit)
                    Hairline()
                    CommitChanges(viewModel: viewModel, placement: layout.filesPlacement)
                case .fileTree:
                    CommitSummaryBar(commit: commit)
                    Hairline()
                    CommitFileTreeTab(viewModel: viewModel)
                }
            }
            .clipped()
        } else {
            EmptyStateView("No Commit Selected", systemImage: "smallcircle.filled.circle", message: "Select a commit to see its details and changes.")
                .accessibilityIdentifier("commitInfo.empty")
        }
    }
}

struct CommitDetailsTabBar: View {
    @Binding var selection: CommitDetailsTab
    var tabs = CommitDetailsTab.allCases
    let placement: CommitDetailsLayout.FilesPlacement
    let toggleFilesPlacement: (() -> Void)?

    var body: some View {
        HStack(spacing: Metrics.Spacing.xxs) {
            ForEach(tabs) { tab in
                CommitDetailsTabButton(tab: tab, isSelected: tab == selection) { selection = tab }
            }
            Spacer(minLength: Metrics.Spacing.s)
            if let toggleFilesPlacement {
                DiffBarButton(
                    systemImage: placement == .beside ? "rectangle.split.2x1" : "rectangle.split.1x2",
                    help: placement.toggled.title,
                    identifier: "commitTabs.layout",
                    action: toggleFilesPlacement
                )
                .accessibilityValue(placement.rawValue)
            }
        }
        .padding(.horizontal, Metrics.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Metrics.CommitDetails.tabBarHeight)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("commitTabs")
    }
}

private struct CommitDetailsTabButton: View {
    let tab: CommitDetailsTab
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            Text(tab.title)
                .font(Metrics.Font.title.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Palette.Text.primary.color : Palette.Text.secondary.color)
                .padding(.horizontal, Metrics.Spacing.m)
                .frame(height: Metrics.CommitDetails.tabHeight)
                .background(
                    RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous)
                        .fill(Palette.Text.primary.color.opacity(isSelected ? Palette.Ink.hover : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("commitTabs.\(tab.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct CommitSummaryBar: View {
    let commit: Commit

    var body: some View {
        let line = CommitSummaryLine(commit: commit)
        HStack(spacing: Metrics.Spacing.s) {
            AuthorAvatarImage(name: commit.author, email: commit.authorEmail, style: .row)
            Text(line.author)
                .foregroundStyle(Palette.Text.primary.color)
                .accessibilityIdentifier("commitSummary.author")
            Text(line.shortHash)
                .font(Metrics.Font.monoCaption)
                .foregroundStyle(Palette.Text.secondary.color)
                .accessibilityIdentifier("commitSummary.hash")
            Text(line.date)
                .foregroundStyle(Palette.Text.secondary.color)
                .monospacedDigit()
                .accessibilityIdentifier("commitSummary.date")
            Text(line.subject)
                .fontWeight(.semibold)
                .foregroundStyle(Palette.Text.primary.color)
                .truncationMode(.tail)
                .layoutPriority(-1)
                .padding(.leading, Metrics.Spacing.xs)
                .accessibilityIdentifier("commitSummary.subject")
        }
        .font(Metrics.Font.title)
        .lineLimit(1)
        .padding(.horizontal, Metrics.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Metrics.CommitDetails.summaryBarHeight)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("commitSummary")
    }
}

private struct CommitOverview: View {
    let viewModel: RepositoryViewModel
    let commit: Commit
    let showsHeader: Bool

    var body: some View {
        let listed = viewModel.listedCommitSummary
        let summary = currentSummary
        List {
            if showsHeader {
                CommitAuthorRow(commit: commit)
                    .commitOverviewRow(height: Metrics.CommitDetails.authorRowHeight)
                CommitFieldRow(label: "SHA") {
                    CommitHashValue(hash: commit.hash, link: viewModel.commitWebLink)
                }
                .commitOverviewRow(height: Metrics.CommitDetails.fieldRowHeight)
                CommitFieldRow(label: "PARENTS") {
                    CommitParentsValue(parents: commit.parents) { hash in Task { await viewModel.selectParent(hash) } }
                }
                .commitOverviewRow(height: Metrics.CommitDetails.fieldRowHeight)
                if !commit.refNames.isEmpty {
                    CommitFieldRow(label: "REFS") {
                        CommitRefsValue(refNames: commit.refNames, labels: RefLabel.labels(for: commit.refNames, remotes: remotes), lane: viewModel.historyLane(of: commit.hash) ?? 0)
                    }
                    .commitOverviewRow(height: Metrics.CommitDetails.refsRowHeight)
                }
                if let signature = summary?.signature {
                    CommitFieldRow(label: "SIGNED") {
                        CommitSignatureValue(signature: signature)
                    }
                    .commitOverviewRow(height: Metrics.CommitDetails.fieldRowHeight)
                }
                if let firstParent = summary?.comparedFirstParent {
                    CommitFieldRow(label: "MERGE") {
                        CommitMergeValue(firstParent: firstParent)
                    }
                    .commitOverviewRow(height: Metrics.CommitDetails.fieldRowHeight)
                }
                CommitMessageRow(message: viewModel.displayedMessage(of: commit))
                    .commitOverviewRow(height: nil)
            }
            if case let .failed(message) = viewModel.commitInfo {
                Label("Could not load the commit: \(message)", systemImage: "exclamationmark.triangle")
                    .font(Metrics.Font.caption)
                    .foregroundStyle(Palette.Text.secondary.color)
                    .commitOverviewRow(height: Metrics.Row.list)
            }
            if let listed, !listed.files.isEmpty {
                CommitFilesHeaderRow(isExpanded: viewModel.areAllInlineDiffsExpanded) {
                    if viewModel.areAllInlineDiffsExpanded { viewModel.collapseAllInlineDiffs() } else { viewModel.expandAllInlineDiffs() }
                }
                .commitOverviewRow(height: Metrics.CommitDetails.filesHeaderHeight)
                ForEach(viewModel.commitTabRows) { row in
                    CommitTabRowView(viewModel: viewModel, row: row, commit: listed.commit)
                }
            }
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, Metrics.CommitDetails.inlineLineHeight)
        .accessibilityIdentifier("commitInfo.details")
        .task(id: listed?.commit.hash) {
            if let listed { await viewModel.loadLFSMarkers(for: listed) }
        }
    }

    private var currentSummary: CommitSummary? {
        if case let .loaded(summary) = viewModel.commitInfo, summary.commit == commit { return summary }
        return nil
    }

    private var remotes: Set<String> {
        Set(viewModel.remoteBranches.compactMap(\.remoteName))
    }
}

extension View {
    func commitOverviewRow(height: CGFloat?) -> some View {
        frame(height: height, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowInsets(EdgeInsets(top: 0, leading: Metrics.CommitDetails.rowInset, bottom: 0, trailing: Metrics.CommitDetails.rowInset))
            .listRowSeparator(.hidden)
    }
}

private struct CommitLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Metrics.Font.label)
            .tracking(Metrics.Font.labelTracking)
            .textCase(.uppercase)
            .foregroundStyle(Palette.Text.secondary.color)
            .lineLimit(1)
    }
}

struct CommitAuthorRow: View {
    let commit: Commit

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.CommitDetails.columnGap) {
            AuthorAvatarImage(name: commit.author, email: commit.authorEmail, style: .author)
                .padding(.top, Metrics.Spacing.xl)
                .frame(width: Metrics.CommitDetails.labelColumnWidth, alignment: .trailing)
            VStack(alignment: .leading, spacing: Metrics.Spacing.xxs) {
                CommitLabel(text: "AUTHOR")
                    .padding(.bottom, Metrics.Spacing.xxs)
                HStack(alignment: .firstTextBaseline, spacing: Metrics.Spacing.s) {
                    SelectableText(commit.author, font: .systemFont(ofSize: Metrics.FontSize.heading, weight: .semibold), identifier: "commitInfo.author")
                        .fixedSize()
                    SelectableText(commit.authorEmail, font: .systemFont(ofSize: Metrics.FontSize.title), color: Palette.Text.secondary.nsColor, identifier: "commitInfo.email")
                }
                SelectableText(CommitSummaryLine.fullDate(commit.date), font: .monospacedDigitSystemFont(ofSize: Metrics.FontSize.title, weight: .regular), color: Palette.Text.secondary.nsColor, identifier: "commitInfo.date")
            }
        }
        .padding(.top, Metrics.Spacing.m)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("commitInfo.header")
    }
}

struct CommitFieldRow<Value: View>: View {
    let label: String
    @ViewBuilder let value: () -> Value

    var body: some View {
        HStack(alignment: .center, spacing: Metrics.CommitDetails.columnGap) {
            CommitLabel(text: label)
                .frame(width: Metrics.CommitDetails.labelColumnWidth, alignment: .trailing)
            value()
        }
        .frame(maxHeight: .infinity)
    }
}

struct CommitHashValue: View {
    let hash: String
    let link: CommitWebLink?
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: Metrics.Spacing.xs) {
            SelectableText(hash, font: .monospacedSystemFont(ofSize: Metrics.FontSize.caption, weight: .regular), identifier: "commitInfo.hash")
                .fixedSize()
            if let link {
                DiffBarButton(systemImage: "safari", help: "Open on \(link.host.title)", identifier: "commitInfo.openOnWeb") {
                    openURL(link.commitURL(hash))
                }
            }
        }
    }
}

private struct CommitParentsValue: View {
    let parents: [String]
    let select: (String) -> Void

    var body: some View {
        HStack(spacing: Metrics.Spacing.s) {
            if parents.isEmpty {
                Text("None (root commit)")
                    .font(Metrics.Font.title)
                    .foregroundStyle(Palette.Text.secondary.color)
            }
            ForEach(parents, id: \.self) { hash in
                Button(action: { select(hash) }) {
                    Text(String(hash.prefix(7)))
                        .foregroundStyle(Palette.Accent.text.color)
                }
                .buttonStyle(.plain)
                .linkCursor()
                .font(Metrics.Font.monoCaption)
                .help("Select parent \(hash)")
                .accessibilityIdentifier("commitInfo.parent.\(hash.prefix(7))")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(text)
        .accessibilityValue(text)
        .accessibilityIdentifier("commitInfo.parents")
    }

    private var text: String {
        parents.isEmpty ? "None (root commit)" : parents.map { String($0.prefix(7)) }.joined(separator: ", ")
    }
}

private struct CommitRefsValue: View {
    let refNames: [String]
    let labels: [RefLabel]
    let lane: Int

    var body: some View {
        HStack(spacing: Metrics.Spacing.xs) {
            ForEach(labels, id: \.self) { RefBadge(label: $0, lane: lane).fixedSize() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(refNames.joined(separator: ", "))
        .accessibilityIdentifier("commitInfo.refs")
    }
}

private struct CommitSignatureValue: View {
    let signature: CommitSignatureDetails

    var body: some View {
        HStack(spacing: Metrics.Spacing.xs) {
            SignatureIcon(status: signature.status)
            Text(text)
        }
        .font(Metrics.Font.title)
        .foregroundStyle(Palette.Text.secondary.color)
        .lineLimit(1)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("commitInfo.signature")
    }

    private var text: String {
        var parts = [signature.status.title]
        if !signature.signer.isEmpty { parts.append("signed by \(signature.signer)") }
        if !signature.key.isEmpty { parts.append("key \(signature.key)") }
        return parts.joined(separator: " · ")
    }
}

private struct CommitMergeValue: View {
    let firstParent: String

    var body: some View {
        HStack(spacing: Metrics.Spacing.xs + Metrics.Spacing.xxs) {
            Image(systemName: "info.circle")
                .accessibilityHidden(true)
            Text("Merge commit: files and diffs are compared with the first parent \(firstParent.prefix(7)).")
                .lineLimit(1)
                .accessibilityIdentifier("commitInfo.firstParent")
        }
        .font(Metrics.Font.caption)
        .foregroundStyle(Palette.Text.secondary.color)
        .padding(.horizontal, Metrics.Spacing.s)
        .padding(.vertical, Metrics.Spacing.xxs)
        .background(Palette.Surface.raised.color, in: RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous))
    }
}

struct CommitMessageRow: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Hairline()
            SelectableText(CommitMessageText.attributed(message), identifier: "commitInfo.message")
                .padding(.leading, Metrics.CommitDetails.labelColumnWidth + Metrics.CommitDetails.columnGap)
                .padding(.vertical, Metrics.CommitDetails.messageSpacing)
            Hairline()
        }
        .padding(.top, Metrics.CommitDetails.messageSpacing)
        .padding(.bottom, Metrics.Spacing.xs)
    }
}

struct CommitFilesHeaderRow: View {
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button(isExpanded ? "Collapse All" : "Expand All", action: toggle)
                .buttonStyle(.plain)
                .font(Metrics.Font.body)
                .foregroundStyle(Palette.Text.secondary.color)
                .accessibilityIdentifier("commitInfo.expandAll")
        }
        .frame(maxHeight: .infinity)
    }
}

private struct CommitTabRowView: View {
    let viewModel: RepositoryViewModel
    let row: CommitTabRow
    let commit: Commit

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CommitOverviewFileRow(file: row.file, isExpanded: row.isExpanded, isLFS: viewModel.isLFSFile(row.file.path, in: commit)) {
                viewModel.toggleInlineDiff(row.file)
            }
            .frame(height: Metrics.Row.list)
            .contentShape(Rectangle())
            .onTapGesture { viewModel.openCommitFile(row.file, in: commit) }
            .contextMenu { CommitFileMenu(viewModel: viewModel, file: row.file, commit: commit) }
            if let detail = row.detail {
                CommitInlineDetail(detail: detail, path: row.file.path) { viewModel.openCommitFile(row.file, in: commit) }
                    .padding(.leading, Metrics.CommitDetails.labelColumnWidth + Metrics.CommitDetails.columnGap)
                    .padding(.bottom, Metrics.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(EdgeInsets(top: 0, leading: Metrics.CommitDetails.rowInset, bottom: 0, trailing: Metrics.CommitDetails.rowInset))
        .listRowSeparator(.hidden)
    }
}

struct CommitInlineDetail: View {
    let detail: CommitTabRow.Detail
    let path: String
    var open: (() -> Void)?

    var body: some View {
        switch detail {
        case let .diff(document):
            InlineDiffView(document: document)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("commitFile.diff.\(path)")
        case let .failed(message):
            Label("Could not load the diff: \(message)", systemImage: "exclamationmark.triangle")
                .font(Metrics.Font.caption)
                .foregroundStyle(Palette.Text.secondary.color)
                .lineLimit(1)
                .frame(height: Metrics.CommitDetails.inlineLineHeight)
        case let .large(lines):
            HStack(spacing: Metrics.Spacing.s) {
                Text("This diff has \(lines.formatted()) lines.")
                    .foregroundStyle(Palette.Text.secondary.color)
                if let open {
                    Button("Open in Changes", action: open)
                        .buttonStyle(.plain)
                        .foregroundStyle(Palette.Accent.text.color)
                        .linkCursor()
                }
            }
            .font(Metrics.Font.caption)
            .frame(height: Metrics.CommitDetails.inlineLineHeight)
        }
    }
}

struct CommitOverviewFileRow: View {
    let file: CommitFileChange
    let isExpanded: Bool
    let isLFS: Bool
    let toggle: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Metrics.CommitDetails.columnGap) {
            HStack(spacing: Metrics.Spacing.xs) {
                Button(action: toggle) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: Metrics.Icon.disclosure, weight: .semibold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundStyle(Palette.Text.secondary.color)
                        .frame(width: Metrics.Indent.disclosure, height: Metrics.Row.list)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Collapse Diff" : "Expand Diff")
                .accessibilityIdentifier("commitFile.disclose.\(file.path)")
                StatusBadge(letter: file.status, color: StatusBadge.color(for: file.status))
                FileIcon(path: file.path)
            }
            .frame(width: Metrics.CommitDetails.labelColumnWidth, alignment: .trailing)
            HStack(spacing: Metrics.Spacing.s) {
                Text(file.path)
                    .font(Metrics.Font.title)
                    .foregroundStyle(Palette.Text.primary.color)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let originalPath = file.originalPath {
                    Text("from \(originalPath)")
                        .font(Metrics.Font.caption)
                        .foregroundStyle(Palette.Text.secondary.color)
                        .lineLimit(1)
                }
                if isLFS { LFSBadge(path: file.path) }
            }
        }
        .frame(maxHeight: .infinity)
        .background(SelectionHighlight(isSelected: false, isHovered: isHovered))
        .onHover { inside in
            guard inside != isHovered else { return }
            isHovered = inside
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(file.path)
        .accessibilityIdentifier("commitFile.\(file.path)")
    }
}

private struct CommitChanges: View {
    @Bindable var viewModel: RepositoryViewModel
    let placement: CommitDetailsLayout.FilesPlacement

    var body: some View {
        switch placement {
        case .beside:
            PaneSplit(
                .horizontal,
                key: PaneSplitKey.changesFilesWidth,
                defaultSize: Metrics.CommitDetails.filesPaneIdealWidth,
                range: Metrics.CommitDetails.filesPaneMinimumWidth...Metrics.CommitDetails.filesPaneMaximumWidth,
                mainMinimum: Metrics.CommitDetails.diffMinimumWidth,
                identifier: "commitFiles.resize"
            ) {
                files
            } main: {
                DetailView(viewModel: viewModel, showsFileHeaderBar: true)
            }
        case .above:
            PaneSplit(
                .vertical,
                key: PaneSplitKey.changesFilesHeight,
                defaultSize: Metrics.CommitDetails.filesAboveIdealHeight,
                range: Metrics.CommitDetails.filesAboveMinimumHeight...Metrics.CommitDetails.filesAboveMaximumHeight,
                mainMinimum: Metrics.CommitDetails.diffBelowMinimumHeight,
                identifier: "commitFiles.resize"
            ) {
                files
            } main: {
                DetailView(viewModel: viewModel, showsFileHeaderBar: true)
            }
        }
    }

    private var files: some View {
        VStack(spacing: 0) {
            CommitFilesFilterRow(viewModel: viewModel)
            Hairline()
            fileContent
        }
    }

    @ViewBuilder
    private var fileContent: some View {
        if let summary = viewModel.listedCommitSummary, !summary.files.isEmpty {
            fileList(summary)
        } else if case let .failed(message) = viewModel.commitInfo {
            EmptyStateView("Could Not Load Commit", systemImage: "exclamationmark.triangle", message: message)
        } else if case .loaded = viewModel.commitInfo {
            EmptyStateView("No File Changes", systemImage: "doc")
                .accessibilityIdentifier("commitInfo.noFiles")
        } else {
            Color.clear
        }
    }

    private func fileList(_ summary: CommitSummary) -> some View {
        let selection = viewModel.selection
        let firstID = viewModel.commitFileRows.first?.id
        return List(selection: $viewModel.selection) {
            ForEach(viewModel.commitFileRows) { row in
                if let file = row.file {
                    let tag = RepositoryViewModel.Selection.commitFile(summary.commit, file)
                    CommitFileListRowView(row: row, isLFS: viewModel.isLFSFile(file.path, in: summary.commit))
                        .background { if tag == selection || row.id == firstID { InkSelectionTableStyle() } }
                        .listRowBackground(tag == selection ? Palette.Accent.tint.color : nil)
                        .tag(tag)
                        .contextMenu { CommitFileMenu(viewModel: viewModel, file: file, commit: summary.commit) }
                        .listRowInsets(Metrics.listRowInsets)
                        .listRowSeparator(.hidden)
                } else {
                    CommitFileListRowView(row: row, isLFS: false)
                        .selectionDisabled()
                        .listRowInsets(Metrics.listRowInsets)
                        .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.inset)
        .environment(\.defaultMinListRowHeight, Metrics.Row.list)
        .onKeyPress(.space) {
            viewModel.toggleFilePreview()
            return .handled
        }
        .onKeyPress(.escape) {
            guard viewModel.isPreviewingFile else { return .ignored }
            viewModel.closeFilePreview()
            return .handled
        }
        .accessibilityIdentifier("commitInfo.files")
        .task(id: summary.commit.hash) { await viewModel.loadLFSMarkers(for: summary) }
    }
}

private struct CommitFilesFilterRow: View {
    @Bindable var viewModel: RepositoryViewModel

    var body: some View {
        FileFilterRow(text: $viewModel.commitFileFilter, identifier: "commitFiles.filter") {
            let next: FileListMode = viewModel.commitFileListMode == .flat ? .tree : .flat
            DiffBarButton(systemImage: next.systemImage, help: next.title, identifier: "commitFiles.mode") {
                viewModel.commitFileListMode = next
            }
            .accessibilityValue(viewModel.commitFileListMode.rawValue)
        }
    }
}

struct FileFilterRow<Trailing: View>: View {
    @Binding var text: String
    let identifier: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: Metrics.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: Metrics.Control.fieldGlyph))
                .foregroundStyle(Palette.Text.tertiary.color)
            TextField("Filter Files", text: $text, prompt: Text("Filter Files").foregroundStyle(Palette.Text.tertiary.color))
                .textFieldStyle(.plain)
                .font(Metrics.Font.body)
                .foregroundStyle(Palette.Text.primary.color)
                .accessibilityIdentifier(identifier)
            trailing
        }
        .padding(.leading, Metrics.Spacing.s)
        .padding(.trailing, Metrics.Spacing.xs)
        .frame(height: Metrics.CommitDetails.filterRowHeight)
    }
}

struct CommitFileListRowView: View {
    let row: CommitFileListRow
    let isLFS: Bool

    var body: some View {
        HStack(spacing: Metrics.ChangeRow.gap) {
            Color.clear.frame(width: CGFloat(row.depth) * Metrics.Indent.level, height: 0)
            switch row.kind {
            case .folder:
                Image(systemName: "folder")
                    .foregroundStyle(Palette.Text.secondary.color)
                    .frame(width: Metrics.Icon.column)
                Text(row.title)
                    .font(Metrics.Font.title)
                    .foregroundStyle(Palette.Text.primary.color)
                    .lineLimit(1)
                    .truncationMode(.head)
            case let .file(file):
                StatusBadge(letter: file.status, color: StatusBadge.color(for: file.status))
                FileIcon(path: file.path)
                PathLabel(path: row.title, style: .plain)
                if isLFS { LFSBadge(path: file.path) }
            }
        }
        .frame(height: Metrics.Row.list)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.file?.path ?? row.title)
        .accessibilityIdentifier(row.file.map { "commitFile.\($0.path)" } ?? "commitFolder.\(row.folderPath ?? "")")
    }
}

private struct CommitFileTreeTab: View {
    let viewModel: RepositoryViewModel

    var body: some View {
        if let tree = viewModel.fileTree {
            CommitTreePanel(session: tree, editorName: viewModel.editorName)
        } else {
            Color.clear
        }
    }
}

private struct CommitFileMenu: View {
    let viewModel: RepositoryViewModel
    let file: CommitFileChange
    let commit: Commit

    var body: some View {
        IntegrationFileMenu(viewModel: viewModel, path: file.path, diffTarget: .commit(commit))
        Divider()
        FileInspectionMenu(viewModel: viewModel, path: file.path, commit: commit, isTracked: file.status != "D")
        CustomCommandsMenu(viewModel: viewModel, location: .file, commit: commit, file: file.path)
    }
}

enum CommitMessageText {
    static func attributed(_ message: String) -> NSAttributedString {
        let parts = message.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        let subject = parts.first.map(String.init) ?? message
        let result = NSMutableAttributedString(string: subject, attributes: [
            .font: NSFont.systemFont(ofSize: Metrics.FontSize.display, weight: .semibold),
            .foregroundColor: Palette.Text.primary.nsColor
        ])
        if parts.count > 1 {
            let body = String(parts[1]).trimmingCharacters(in: .newlines)
            if !body.isEmpty {
                result.append(NSAttributedString(string: "\n\n" + body, attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: Metrics.FontSize.body, weight: .regular),
                    .foregroundColor: Palette.Text.primary.nsColor
                ]))
            }
        }
        return result
    }
}
