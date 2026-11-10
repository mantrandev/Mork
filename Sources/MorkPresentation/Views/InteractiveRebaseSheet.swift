import MorkDomain
import SwiftUI

struct InteractiveRebaseSheet: View {
    @Bindable var session: InteractiveRebaseViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            RebaseHeader(session: session)
            Hairline()
            PaneSplit(
                .vertical,
                key: PaneSplitKey.rebaseStepsHeight,
                defaultSize: Metrics.Rebase.stepsIdealHeight,
                range: Metrics.Rebase.stepsMinimumHeight...Metrics.Rebase.stepsMaximumHeight,
                mainMinimum: Metrics.Rebase.detailsMinimumHeight,
                identifier: "rebaseSheet.resize"
            ) {
                List(selection: $session.selectedStepID) {
                    ForEach(session.displayedSteps) { step in
                        RebaseStepRow(session: session, step: step)
                            .frame(height: Metrics.Rebase.rowHeight)
                            .listRowInsets(EdgeInsets(top: 0, leading: Metrics.Spacing.s, bottom: 0, trailing: Metrics.Spacing.s))
                            .tag(step.id)
                    }
                    .onMove { session.moveDisplayed(fromOffsets: $0, toOffset: $1) }
                }
                .environment(\.defaultMinListRowHeight, Metrics.Rebase.rowHeight)
                .onKeyPress(keys: [.upArrow, .downArrow]) { press in
                    guard press.modifiers == .command else { return .ignored }
                    session.moveSelected(press.key == .upArrow ? .up : .down)
                    return .handled
                }
                .onKeyPress { press in
                    guard press.modifiers.isEmpty, let key = press.characters.first, session.applyShortcut(key) else { return .ignored }
                    return .handled
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .accessibilityIdentifier("rebaseSheet.steps")
            } main: {
                RebaseDetails(session: session)
            }
            Hairline()
            RebaseFooter(session: session) { dismiss() }
        }
        .frame(minWidth: Metrics.Rebase.minimumWidth, idealWidth: Metrics.Sheet.largeWidth, minHeight: Metrics.Rebase.minimumHeight, idealHeight: Metrics.Rebase.idealHeight)
        .dialogSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("rebaseSheet")
        .sheet(item: Binding(get: { session.messageDraft }, set: { if $0 == nil { session.cancelMessageEdit() } })) { draft in
            RebaseMessageSheet(session: session, draft: draft)
        }
    }
}

private extension RebaseAction {
    var title: String { rawValue.capitalized }

    var summary: String {
        switch self {
        case .pick: "Use commit"
        case .edit: "Stop for amending"
        case .reword: "Edit the commit message"
        case .squash: "Meld commit into previous one and keep message"
        case .fixup: "Meld commit into previous one and discard message"
        case .drop: "Remove commit"
        }
    }

    var color: Color {
        switch self {
        case .pick: Palette.Status.added.ink.color
        case .edit, .reword: Palette.Status.conflict.ink.color
        case .squash, .fixup: Palette.Status.untracked.ink.color
        case .drop: Palette.Status.deleted.ink.color
        }
    }
}

private struct RebaseHeader: View {
    let session: InteractiveRebaseViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.m) {
            DialogHeader(kind: .options, glyph: "list.bullet.indent", title: "Interactive Rebase")
            HStack(spacing: Metrics.Spacing.l) {
                HStack(spacing: Metrics.Spacing.s) {
                    Text("Rebase").foregroundStyle(Palette.Text.secondary.color)
                    Label(session.branchName, systemImage: "arrow.triangle.branch")
                        .foregroundStyle(Palette.Text.primary.color)
                        .accessibilityIdentifier("rebaseSheet.branch")
                }
                Spacer(minLength: Metrics.Spacing.l)
                HStack(spacing: Metrics.Spacing.s) {
                    Text("On").foregroundStyle(Palette.Text.secondary.color)
                    switch session.base {
                    case let .commit(commit):
                        Image(systemName: "smallcircle.filled.circle").foregroundStyle(Palette.Text.secondary.color)
                        Text(commit.shortHash).font(Metrics.Font.monoCaption).foregroundStyle(Palette.Accent.text.color)
                        Text(commit.subject).foregroundStyle(Palette.Text.primary.color).lineLimit(1).truncationMode(.tail)
                    case let .branch(branch):
                        Label(branch.name, systemImage: "arrow.triangle.branch").foregroundStyle(Palette.Text.primary.color)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("rebaseSheet.base")
            }
            .font(Metrics.Font.title)
        }
        .padding(.horizontal, Metrics.Sheet.padding)
        .padding(.top, Metrics.Sheet.padding)
        .padding(.bottom, Metrics.Spacing.m)
    }
}

private struct RebaseStepRow: View {
    let session: InteractiveRebaseViewModel
    let step: RebaseStep

    private var identifier: String { "rebaseStep.\(step.commit.subject)" }
    private var shownSubject: String {
        step.action == .reword ? step.message.components(separatedBy: .newlines).first ?? "" : step.commit.subject
    }

    var body: some View {
        HStack(spacing: Metrics.Spacing.xs) {
            RebaseActionMenu(session: session, step: step, isSelected: session.selectedStepID == step.id)
                .frame(width: Metrics.Rebase.actionColumn, alignment: .leading)
                .help("\(step.action.title): \(step.action.explanation)")
                .accessibilityIdentifier("\(identifier).action")
            MeldArrow(marker: session.meldMarkers[step.id] ?? [])
                .frame(width: Metrics.Rebase.meldColumn, height: Metrics.Rebase.rowHeight)
            Text(shownSubject)
                .font(Metrics.Font.body)
                .lineLimit(1)
                .truncationMode(.tail)
                .strikethrough(step.action == .drop)
                .foregroundStyle(step.action == .drop ? Palette.Text.secondary.color : Palette.Text.primary.color)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                session.editMessage(for: step.id)
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Palette.Text.secondary.color)
                    .frame(width: Metrics.HitTarget.inline, height: Metrics.HitTarget.inline)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Edit the message: rewords this commit")
            .accessibilityLabel("Edit Message")
            .accessibilityIdentifier("\(identifier).edit")
            AuthorAvatarImage(name: step.commit.author, email: step.commit.authorEmail, style: .row)
            Text(step.commit.author)
                .font(Metrics.Font.body)
                .foregroundStyle(Palette.Text.secondary.color)
                .lineLimit(1)
                .frame(width: Metrics.Rebase.authorColumn, alignment: .leading)
            Text(step.commit.shortHash)
                .font(Metrics.Font.monoCaption)
                .foregroundStyle(Palette.Text.secondary.color)
                .frame(width: Metrics.Rebase.hashColumn, alignment: .leading)
            Text(step.commit.date.formatted(date: .abbreviated, time: .shortened))
                .font(Metrics.Font.caption.monospacedDigit())
                .lineLimit(1)
                .foregroundStyle(Palette.Text.secondary.color)
                .frame(width: Metrics.Rebase.dateColumn, alignment: .trailing)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
        .accessibilityValue(step.action.rawValue)
    }
}

private struct RebaseActionMenu: View {
    let session: InteractiveRebaseViewModel
    let step: RebaseStep
    let isSelected: Bool
    @State private var isHovered = false
    @State private var dropdown = DropdownPanel()

    private var isActive: Bool { isHovered || isSelected || dropdown.isShown }

    var body: some View {
        Button(action: open) {
            HStack(spacing: Metrics.Spacing.s) {
                Circle()
                    .fill(step.action.color)
                    .frame(width: Metrics.Rebase.dot, height: Metrics.Rebase.dot)
                Text(step.action.title)
                    .font(Metrics.Font.body.weight(.medium))
                    .foregroundStyle(Palette.Text.primary.color)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: Metrics.Icon.menuIndicator, weight: .bold))
                    .foregroundStyle(Palette.Text.secondary.color)
                    .opacity(isActive ? 1 : 0)
            }
            .padding(.horizontal, Metrics.Spacing.xs)
            .padding(.vertical, Metrics.Spacing.xxs)
            .background {
                RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous)
                    .fill(Palette.Text.primary.color.opacity(isSelected ? Palette.Ink.laneFill : Palette.Ink.selection))
                    .opacity(isActive ? 1 : 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .background(DropdownAnchorView(panel: dropdown))
    }

    private func open() {
        session.selectedStepID = step.id
        let actions = RebaseAction.allCases.map { action in
            MenuEntry(
                title: action.title,
                dotColor: action.color,
                detail: action.summary,
                isChecked: step.action == action,
                keyEquivalent: String(action.abbreviation).uppercased(),
                identifier: "rebaseAction.\(action.rawValue)"
            ) { session.setAction(action, for: step.id) }
        }
        dropdown.show(identifier: "rebaseActionMenu", minimumWidth: Metrics.Rebase.menuWidth, rowHeight: Metrics.Dropdown.compactRow, actions + [
            .separator,
            MenuEntry(title: "Move up", keyEquivalent: "⌘▲", identifier: "rebaseAction.moveUp", isEnabled: session.canMoveSelected(.up)) { session.moveSelected(.up) },
            MenuEntry(title: "Move down", keyEquivalent: "⌘▼", identifier: "rebaseAction.moveDown", isEnabled: session.canMoveSelected(.down)) { session.moveSelected(.down) }
        ])
    }
}

private struct MeldArrow: View {
    let marker: MeldMarker

    var body: some View {
        Canvas { context, size in
            let x = size.width * Metrics.Rebase.meldLineFraction
            let middle = size.height / 2
            let curve = Metrics.Rebase.meldCurve
            var path = Path()
            if marker.contains(.through) {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            if marker.contains(.start) {
                path.move(to: CGPoint(x: x, y: middle))
                path.addLine(to: CGPoint(x: x, y: size.height))
                let dot = Metrics.Rebase.meldDot
                context.fill(Path(ellipseIn: CGRect(x: x - dot / 2, y: middle - dot / 2, width: dot, height: dot)), with: .foreground)
            }
            if marker.contains(.end) {
                let tip = size.width - Metrics.Spacing.xxs
                let head = Metrics.Rebase.meldArrowHead
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: middle - curve))
                path.addQuadCurve(to: CGPoint(x: x + curve, y: middle), control: CGPoint(x: x, y: middle))
                path.addLine(to: CGPoint(x: tip, y: middle))
                var arrow = Path()
                arrow.move(to: CGPoint(x: tip, y: middle))
                arrow.addLine(to: CGPoint(x: tip - head * Metrics.Rebase.meldArrowLength, y: middle - head))
                arrow.addLine(to: CGPoint(x: tip - head * Metrics.Rebase.meldArrowLength, y: middle + head))
                arrow.closeSubpath()
                context.fill(arrow, with: .foreground)
            }
            context.stroke(path, with: .foreground, style: StrokeStyle(lineWidth: Metrics.Rebase.meldLine, lineCap: .round))
        }
        .foregroundStyle(Palette.Text.secondary.color)
        .accessibilityHidden(true)
    }
}

struct RebaseMessageSheet: View {
    let session: InteractiveRebaseViewModel
    @State var draft: RebaseMessageDraft

    var body: some View {
        DialogScaffold(kind: .form, glyph: "pencil", title: "Reword \(draft.shortHash)") {
            DialogLabeledRow("Subject") {
                DialogTextField(placeholder: "Commit title", text: $draft.subject, identifier: "rebaseMessage.subject") {
                    session.saveMessage(draft)
                }
            }
            DialogLabeledRow("Description") {
                DialogTextEditor(placeholder: "optional", text: $draft.description, height: Metrics.Rebase.descriptionHeight, identifier: "rebaseMessage.description")
            }
        } buttons: {
            DialogCancelButton(identifier: "rebaseMessage.cancel") { session.cancelMessageEdit() }
            DialogConfirmButton(title: "Save", identifier: "rebaseMessage.save") { session.saveMessage(draft) }
                .disabled(!draft.canSave)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("rebaseMessage")
    }
}

private struct RebaseDetails: View {
    let session: InteractiveRebaseViewModel
    @AppStorage("rebase.detailsTab") private var storedTab = RebaseDetailsTab.changes

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Details", selection: Binding(
                    get: { session.detailsTab },
                    set: { session.detailsTab = $0; storedTab = $0 }
                )) {
                    ForEach(RebaseDetailsTab.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .accessibilityIdentifier("rebaseSheet.detailsTab")
                Spacer()
            }
            .padding(.horizontal, Metrics.Sheet.padding)
            .padding(.vertical, Metrics.Spacing.s)
            Hairline()
            switch session.detailsTab {
            case .commit:
                if let step = session.selectedStep {
                    RebaseCommitDetails(session: session, step: step)
                } else {
                    EmptyStateView("No Commit Selected", systemImage: "smallcircle.filled.circle", message: "Select a commit to see its details.")
                }
            case .changes:
                if let step = session.selectedStep {
                    RebaseChanges(session: session, commit: step.commit)
                } else {
                    EmptyStateView("No Commit Selected", systemImage: "smallcircle.filled.circle", message: "Select a commit to see its changes.")
                }
            case .todo:
                TodoPreview(session: session)
            }
        }
        .onAppear { session.detailsTab = storedTab }
    }
}

private struct RebaseChanges: View {
    @Bindable var session: InteractiveRebaseViewModel
    let commit: Commit

    var body: some View {
        VStack(spacing: 0) {
            CommitSummaryBar(commit: commit)
            Hairline()
            PaneSplit(
                .horizontal,
                key: PaneSplitKey.rebaseChangesFilesWidth,
                defaultSize: Metrics.CommitDetails.filesPaneIdealWidth,
                range: Metrics.CommitDetails.filesPaneMinimumWidth...Metrics.CommitDetails.filesPaneMaximumWidth,
                mainMinimum: Metrics.CommitDetails.diffMinimumWidth,
                identifier: "rebaseChanges.resize"
            ) {
                VStack(spacing: 0) {
                    FileFilterRow(text: $session.changesFilter, identifier: "rebaseChanges.filter") {
                        let next: FileListMode = session.changesFileListMode == .flat ? .tree : .flat
                        DiffBarButton(systemImage: next.systemImage, help: next.title, identifier: "rebaseChanges.mode") {
                            session.changesFileListMode = next
                        }
                        .accessibilityValue(session.changesFileListMode.rawValue)
                    }
                    Hairline()
                    files
                }
            } main: {
                RebaseChangesDiff(session: session)
            }
        }
        .accessibilityIdentifier("rebaseSheet.changes")
    }

    @ViewBuilder
    private var files: some View {
        switch session.commitFiles {
        case let .loaded(files) where !files.isEmpty:
            fileList
        case .loaded:
            EmptyStateView("No File Changes", systemImage: "doc")
        case let .failed(message):
            EmptyStateView("Could Not Load Commit", systemImage: "exclamationmark.triangle", message: message)
        case .loading, nil:
            Color.clear
        }
    }

    private var fileList: some View {
        let selection = session.selectedChangesPath
        let firstID = session.changesRows.first?.id
        return List(selection: $session.selectedChangesPath) {
            ForEach(session.changesRows) { row in
                if let file = row.file {
                    CommitFileListRowView(row: row, isLFS: false)
                        .background { if file.path == selection || row.id == firstID { InkSelectionTableStyle() } }
                        .listRowBackground(file.path == selection ? Palette.Accent.tint.color : nil)
                        .tag(file.path)
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
        .accessibilityIdentifier("rebaseChanges.files")
    }
}

private struct RebaseChangesDiff: View {
    let session: InteractiveRebaseViewModel
    @Environment(\.diffMetrics) private var metrics
    @State private var showsRaw = false
    @State private var hunkJump = DiffHunkJump(id: 0, direction: .next)

    var body: some View {
        switch session.changesDiff {
        case nil where session.selectedChangesFile == nil:
            EmptyStateView("No File Selected", systemImage: "doc.text", message: "Select a file to see its changes.")
        case nil, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .failed(message):
            EmptyStateView("Could Not Load", systemImage: "exclamationmark.triangle", message: message)
        case let .loaded(document):
            if document.lines.isEmpty {
                EmptyStateView("No Differences", systemImage: "equal")
            } else if document.isCollapsed {
                LargeDiffPlaceholder(lineCount: document.totalLines, show: session.showLargeChangesDiff)
            } else if case let .file(header, meta, additions, deletions)? = document.blocks.first, document.blocks.dropFirst().allSatisfy({ if case .file = $0 { false } else { true } }) {
                let options = session.diffSettings
                VStack(spacing: 0) {
                    DiffFileHeaderBar(
                        summary: DiffFileSummary(header: ([header] + meta).map(\.text), additions: additions, deletions: deletions),
                        rawLines: ([header] + meta).map(\.text),
                        showsRaw: showsRaw,
                        toggleRaw: { showsRaw.toggle() },
                        jump: { direction in hunkJump = DiffHunkJump(id: hunkJump.id + 1, direction: direction) },
                        options: options,
                        changeOptions: { session.changeDiffSettings($0) }
                    )
                    Hairline()
                    if options.showsSideBySide {
                        SplitDiffTableView(document: document, metrics: metrics)
                    } else {
                        DiffText(document: document, hidesFileCards: true, hunkJump: hunkJump)
                    }
                }
            } else {
                DiffText(document: document, showsRawDiff: showsRaw, toggleRawDiff: { showsRaw.toggle() })
            }
        }
    }
}

private struct RebaseCommitDetails: View {
    let session: InteractiveRebaseViewModel
    let step: RebaseStep

    var body: some View {
        List {
            CommitAuthorRow(commit: step.commit)
                .commitOverviewRow(height: Metrics.CommitDetails.authorRowHeight)
            CommitFieldRow(label: "SHA") {
                CommitHashValue(hash: step.commit.hash, link: nil)
            }
            .commitOverviewRow(height: Metrics.CommitDetails.fieldRowHeight)
            CommitMessageRow(message: step.action == .reword ? step.message : step.originalMessage)
                .commitOverviewRow(height: nil)
            if case let .failed(message) = session.commitFiles {
                Label("Could not load the changes: \(message)", systemImage: "exclamationmark.triangle")
                    .font(Metrics.Font.caption)
                    .foregroundStyle(Palette.Text.secondary.color)
                    .commitOverviewRow(height: Metrics.Row.list)
            }
            if !session.commitTabRows.isEmpty {
                CommitFilesHeaderRow(isExpanded: session.areAllInlineDiffsExpanded) {
                    if session.areAllInlineDiffsExpanded { session.collapseAllInlineDiffs() } else { session.expandAllInlineDiffs() }
                }
                .commitOverviewRow(height: Metrics.CommitDetails.filesHeaderHeight)
                ForEach(session.commitTabRows) { row in
                    RebaseFileRow(session: session, row: row)
                }
            }
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, Metrics.CommitDetails.inlineLineHeight)
        .accessibilityIdentifier("rebaseSheet.commit")
    }
}

private struct RebaseFileRow: View {
    let session: InteractiveRebaseViewModel
    let row: CommitTabRow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CommitOverviewFileRow(file: row.file, isExpanded: row.isExpanded, isLFS: false) {
                session.toggleInlineDiff(row.file)
            }
            .frame(height: Metrics.Row.list)
            .contentShape(Rectangle())
            .onTapGesture { session.toggleInlineDiff(row.file) }
            if let detail = row.detail {
                CommitInlineDetail(detail: detail, path: row.file.path)
                    .padding(.leading, Metrics.CommitDetails.labelColumnWidth + Metrics.CommitDetails.columnGap)
                    .padding(.bottom, Metrics.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(EdgeInsets(top: 0, leading: Metrics.CommitDetails.rowInset, bottom: 0, trailing: Metrics.CommitDetails.rowInset))
        .listRowSeparator(.hidden)
    }
}

private struct TodoPreview: View {
    let session: InteractiveRebaseViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.Spacing.m) {
                Text("Git replays these lines from top to bottom, oldest first. The list above shows the newest commit on top, like the history.")
                    .font(Metrics.Font.body)
                    .foregroundStyle(Palette.Text.secondary.color)
                Text(session.preview.isEmpty ? " " : session.preview)
                    .font(Metrics.Font.monoBody)
                    .foregroundStyle(Palette.Text.primary.color)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("rebaseSheet.preview")
                    .id(session.preview)
                ForEach(session.rewordMessages, id: \.shortHash) { reword in
                    Text("message for \(reword.shortHash), written by GIT_EDITOR:\n\(reword.message)")
                        .font(Metrics.Font.monoBody)
                        .foregroundStyle(Palette.Text.secondary.color)
                        .textSelection(.enabled)
                }
            }
            .padding(Metrics.Sheet.padding)
        }
    }
}

private struct RebaseFooter: View {
    let session: InteractiveRebaseViewModel
    let close: () -> Void
    @AppStorage("rebase.updateDependentBranches") private var storedUpdateRefs = false
    @AppStorage("rebase.createBackup") private var storedBackup = false

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Sheet.rowSpacing) {
            if let message = session.validationMessage {
                DialogNote(text: message, tone: .danger)
                    .accessibilityIdentifier("rebaseSheet.validation")
            }
            if let notice = session.skippedMergesNotice {
                DialogNote(text: notice)
                    .accessibilityIdentifier("rebaseSheet.skippedMerges")
            }
            if session.hasUncommittedChanges {
                DialogNote(text: "You have uncommitted changes. --autostash stashes them before the rebase and applies them again afterwards.", tone: .warning)
                    .accessibilityIdentifier("rebaseSheet.autostash")
            }
            HStack(alignment: .top, spacing: Metrics.Spacing.l) {
                DialogOptionToggle(title: "Update dependent branches", isOn: Binding(
                    get: { session.updatesDependentBranches },
                    set: { session.updatesDependentBranches = $0; storedUpdateRefs = $0 }
                ))
                .help("git rebase --update-refs: other local branches that point at commits in this range move along with the rebased commits.")
                .accessibilityIdentifier("rebaseSheet.updateRefs")
                DialogOptionToggle(title: "Backup current state with temporary branch", isOn: Binding(
                    get: { session.createsBackup },
                    set: { session.createsBackup = $0; storedBackup = $0 }
                ))
                .help("Creates \(session.branchName)-backup-<date-time> at the current HEAD before the rebase, so you can reset back to it.")
                .accessibilityIdentifier("rebaseSheet.backup")
            }
            .onAppear {
                session.updatesDependentBranches = storedUpdateRefs
                session.createsBackup = storedBackup
            }
            CommandStrip(command: session.command, identifier: "rebaseSheet.command")
            DialogButtonRow {
                DialogCancelButton(identifier: "rebaseSheet.cancel", action: close)
                DialogConfirmButton(title: session.startTitle, identifier: "rebaseSheet.start") {
                    Task {
                        await session.start()
                        close()
                    }
                }
                .disabled(!session.canStart)
            }
        }
        .padding(.horizontal, Metrics.Sheet.padding)
        .padding(.top, Metrics.Spacing.m)
        .padding(.bottom, Metrics.Sheet.padding)
    }
}
