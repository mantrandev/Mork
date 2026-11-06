import MorkDomain
import SwiftUI

struct ConflictResolverView: View {
    @Bindable var resolver: ConflictResolverViewModel
    let repository: RepositoryViewModel
    var isInWindow = false
    @State private var pendingDelete = false
    @State private var showsMarkerLesson = false
    @State private var savedBlocksHeight: CGFloat?
    @State private var cardHeights: [Int: CGFloat] = [:]
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
                .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }, action: { contentHeight = $0 })
                .clipped()
        }
        .background(Palette.Surface.window.color)
        .morkConfirmation(isPresented: $pendingDelete) {
            .deleteConflictedFile(resolver.path, identifier: "conflict.delete.confirm") { Task { await resolver.resolve(.delete) } }
        }
        .morkConfirmation(item: Binding(get: { ownsDialogs ? resolver.pendingMarkResolved : nil }, set: { resolver.pendingMarkResolved = $0 })) { remaining in
            MorkConfirmation(
                kind: .warning,
                title: "Stage \(resolver.path) with conflict markers?",
                message: "\(remaining) conflict \(remaining == 1 ? "block still has" : "blocks still have") <<<<<<< markers. git add stages the file exactly as it is, markers included. Fix the markers and stage the file again to correct it.",
                commands: [DialogCommands.markResolved(resolver.path)],
                actions: [confirmationAction],
                cancelIdentifier: "conflict.markResolved.cancel"
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("conflict.resolver")
    }

    private var ownsDialogs: Bool {
        isInWindow == (repository.conflictWindowPath == resolver.path)
    }

    private var confirmationAction: DialogAction {
        resolver.confirmationSaves
            ? DialogAction(title: "Save and Mark Resolved", isDestructive: true, identifier: "conflict.markResolved.confirm") { Task { await resolver.confirmMarkResolved() } }
            : DialogAction(title: "Mark as Resolved", isDestructive: true, identifier: "conflict.markResolved.confirm") { Task { await resolver.confirmMarkResolved() } }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.s - 2) {
            HStack(spacing: Metrics.Spacing.s) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Palette.Status.conflict.ink.color)
                FileIcon(path: resolver.path)
                FilePathText(path: resolver.path, originalPath: nil)
                    .font(Metrics.Font.title)
                if let kind = resolver.kind {
                    Text("\(kind.title) · \(kind.statusCode)")
                        .font(Metrics.Font.caption.weight(.semibold))
                        .foregroundStyle(Palette.Status.conflict.ink.color)
                        .fixedSize()
                        .accessibilityIdentifier("conflict.kind")
                }
                Button { showsMarkerLesson.toggle() } label: {
                    Label("What are conflict markers?", systemImage: "questionmark.circle")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(Palette.Text.secondary.color)
                }
                .buttonStyle(.borderless)
                .help("What do <<<<<<<, ======= and >>>>>>> mean?")
                .popover(isPresented: $showsMarkerLesson, arrowEdge: .bottom) {
                    Text(Lessons.conflictMarkers)
                        .font(Metrics.Font.body)
                        .foregroundStyle(Palette.Text.primary.color)
                        .textSelection(.enabled)
                        .padding(Metrics.Spacing.l)
                        .frame(width: Metrics.Conflict.lessonWidth, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityIdentifier("conflict.markersLesson")
            }
            if let kind = resolver.kind {
                Text(kind.explanation)
                    .font(Metrics.Font.body)
                    .foregroundStyle(Palette.Text.secondary.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let hint = resolver.sideHint {
                Label(hint, systemImage: "info.circle")
                    .font(Metrics.Font.caption)
                    .foregroundStyle(Palette.Text.secondary.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: Metrics.Spacing.s - 2) {
                ForEach(resolver.fileResolutions, id: \.self) { resolution in
                    Button(resolution.title, role: resolution == .delete ? .destructive : nil) {
                        if resolution == .delete {
                            pendingDelete = true
                        } else {
                            Task { await resolver.resolve(resolution) }
                        }
                    }
                    .buttonStyle(.mork(resolution == .delete ? .destructive : .secondary, size: .small))
                    .help(resolution.command(for: resolver.path))
                    .accessibilityIdentifier("conflict.resolve.\(resolution.rawValue)")
                }
                if resolver.canMarkResolved {
                    Button("Mark as Resolved") { Task { await resolver.markResolved() } }
                        .buttonStyle(.mork(.secondary, size: .small))
                        .help("git add -- \(ShellWords.quote(resolver.path))")
                        .accessibilityIdentifier("conflict.markResolved")
                }
                OpenInMergeToolButton(repository: repository, resolver: resolver)
            }
            .controlSize(.small)
            .disabled(resolver.isWorking || isToolRunning)
            MergeToolBar(repository: repository, resolver: resolver)
        }
        .padding(.horizontal, Metrics.Spacing.m)
        .padding(.vertical, Metrics.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.Surface.raised.color)
        .overlay(alignment: .leading) {
            Palette.Status.conflict.ink.color.frame(width: Metrics.Conflict.accentBar)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch resolver.state {
        case .loading:
            ProgressView()
        case let .failed(message):
            EmptyStateView("Could Not Read the File", systemImage: "exclamationmark.triangle", message: message)
        case let .loaded(file):
            switch file.content {
            case .binary:
                EmptyStateView(
                    "Binary Conflict",
                    systemImage: "doc.badge.gearshape",
                    message: "Git cannot merge binary files line by line, so there are no blocks to pick. Resolve the whole file with Ours or Theirs."
                )
                .accessibilityIdentifier("conflict.binary")
            case .missing:
                EmptyStateView("No File on Disk", systemImage: "trash", message: file.kind.explanation)
                    .accessibilityIdentifier("conflict.missing")
            case .text:
                if !resolver.hasBlocksToResolve {
                    if file.kind.hasContentConflict {
                        EmptyStateView(
                            "No Markers Left",
                            systemImage: "checkmark.circle",
                            message: "The file has no conflict markers anymore. Mark it as resolved to stage it."
                        )
                        .accessibilityIdentifier("conflict.noMarkers")
                    } else {
                        ConflictResultPane(title: "File on disk", resolver: resolver)
                    }
                } else {
                    VStack(spacing: 0) {
                        List(resolver.blocks) { block in
                            ConflictBlockCard(
                                block: block,
                                count: resolver.blocks.count,
                                isEnabled: resolver.canChoose(block.id)
                            ) { choice in
                                resolver.choose(choice, for: block.id)
                            }
                            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }, action: { cardHeights[block.id] = $0 })
                            .listRowInsets(EdgeInsets(top: Metrics.Spacing.xxs, leading: Metrics.Spacing.m, bottom: Metrics.Spacing.xxs, trailing: Metrics.Spacing.m))
                            .listRowSeparator(.hidden)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .frame(height: blocksHeight)
                        .accessibilityIdentifier("conflict.blocks")
                        PanelResizeHandle(height: Binding(get: { blocksHeight }, set: { savedBlocksHeight = $0 }), range: Metrics.Conflict.blocksMinimumHeight...Metrics.Conflict.blocksMaximumHeight, growsDownward: true, identifier: "conflict.resize")
                        ConflictResultPane(title: "Result", resolver: resolver)
                            .frame(minHeight: Metrics.Conflict.resultMinimumHeight + Metrics.Panel.header + Metrics.Line.hairline, maxHeight: .infinity)
                        footer
                    }
                }
            }
        }
    }

    private var blocksHeight: CGFloat {
        RepositoryPaneLayout.conflictBlocksHeight(saved: savedBlocksHeight, firstCardHeight: firstCardHeight, cardsHeight: cardsHeight, available: contentHeight)
    }

    private var firstCardHeight: CGFloat? {
        cardHeights[0].map { $0 + Metrics.Spacing.xs * 2 }
    }

    private var cardsHeight: CGFloat? {
        guard cardHeights.count == resolver.blocks.count else { return nil }
        return cardHeights.values.reduce(0, +) + CGFloat(cardHeights.count) * Metrics.Spacing.xs + Metrics.Spacing.s
    }

    private var isToolRunning: Bool {
        repository.externalTools.run(for: resolver.path) != nil
    }

    private var footer: some View {
        HStack(spacing: Metrics.Spacing.s) {
            Text(resolver.progressText)
                .font(Metrics.Font.body)
                .foregroundStyle(resolver.markerCount == 0 ? Palette.Status.added.ink.color : Palette.Text.secondary.color)
                .accessibilityIdentifier("conflict.progress")
            Spacer()
            Button("Reset") { resolver.reset() }
                .buttonStyle(.morkSecondary)
                .disabled(!resolver.hasChanges || resolver.isWorking)
                .help("Put back the text as it was loaded, markers included")
                .accessibilityIdentifier("conflict.reset")
            Button("Save and Mark Resolved") { Task { await resolver.save() } }
                .buttonStyle(.morkPrimary)
                .disabled(!resolver.canSave || isToolRunning)
                .help("Write the result to \(resolver.path), then git add -- \(ShellWords.quote(resolver.path))")
                .accessibilityIdentifier("conflict.save")
        }
        .padding(.horizontal, Metrics.Spacing.m)
        .frame(height: Metrics.Conflict.footerHeight)
        .background(Palette.Surface.raised.color)
        .overlay(alignment: .top) { Divider() }
    }
}

struct ConflictCommitStrip: View {
    let note: String

    var body: some View {
        HStack(spacing: Metrics.Spacing.s) {
            Image(systemName: "info.circle")
                .foregroundStyle(Palette.Text.secondary.color)
            Text(note)
                .font(Metrics.Font.body)
                .foregroundStyle(Palette.Text.secondary.color)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.Spacing.m)
        .frame(height: Metrics.Conflict.commitStripHeight)
        .frame(maxWidth: .infinity)
        .background(Palette.Surface.raised.color)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("conflict.commitNote")
    }
}

private struct ConflictBlockCard: View {
    let block: ConflictBlockView
    let count: Int
    let isEnabled: Bool
    let choose: (ConflictChoice) -> Void
    @State private var width: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.s) {
            HStack(spacing: Metrics.Spacing.s) {
                Text("Conflict \(block.id + 1) of \(count)")
                    .font(Metrics.Font.body.weight(.semibold))
                    .foregroundStyle(Palette.Text.primary.color)
                    .lineLimit(1)
                Spacer(minLength: 0)
                choices
            }
            .frame(height: Metrics.Control.small)
            if showsThreeColumns {
                HStack(alignment: .top, spacing: Metrics.Spacing.s) {
                    ours
                    base
                    theirs
                }
            } else {
                HStack(alignment: .top, spacing: Metrics.Spacing.s) {
                    ours
                    theirs
                }
                base
            }
        }
        .padding(Metrics.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }, action: { width = $0 })
        .background(Palette.Surface.raised.color, in: RoundedRectangle(cornerRadius: Metrics.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metrics.Radius.card, style: .continuous).strokeBorder(block.state == .unresolved ? Palette.Status.conflict.ink.color : Palette.Surface.borderStrong.color, lineWidth: Metrics.Conflict.border))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("conflict.block.\(block.id)")
    }

    @ViewBuilder
    private var choices: some View {
        if let status = block.state.status {
            HStack(spacing: Metrics.Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Palette.Status.added.ink.color)
                Text(status)
                    .font(Metrics.Font.body.weight(.medium))
                    .foregroundStyle(Palette.Text.primary.color)
            }
            .fixedSize()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Resolved: \(status)")
            .accessibilityIdentifier("conflict.block.\(block.id).status")
        } else {
            HStack(spacing: Metrics.Spacing.s - 2) {
                ForEach(ConflictChoice.allCases, id: \.self) { option in
                    Button(option.title) { choose(option) }
                        .buttonStyle(.mork(.secondary, size: .small))
                        .help(option.help)
                        .accessibilityIdentifier("conflict.block.\(block.id).\(option.rawValue)")
                }
            }
            .fixedSize()
            .controlSize(.small)
            .disabled(!isEnabled)
        }
    }

    private var showsThreeColumns: Bool {
        width - Metrics.Spacing.s * 2 >= 3 * Metrics.Conflict.sideMinimumWidth
    }

    private var ours: some View {
        ConflictSideColumn(title: "Ours", label: block.block.oursLabel, lineCount: block.ours.count, text: block.oursText, status: .modified)
            .accessibilityIdentifier("conflict.block.\(block.id).oursText")
    }

    @ViewBuilder
    private var base: some View {
        if let base = block.base, let text = block.baseText {
            ConflictSideColumn(title: "Base", label: block.baseCaption ?? "", lineCount: base.count, text: text, status: .untracked)
                .accessibilityIdentifier("conflict.block.\(block.id).base")
        }
    }

    private var theirs: some View {
        ConflictSideColumn(title: "Theirs", label: block.block.theirsLabel, lineCount: block.theirs.count, text: block.theirsText, status: .renamed)
            .accessibilityIdentifier("conflict.block.\(block.id).theirsText")
    }
}

private struct ConflictSideColumn: View {
    static let lineHeight = Metrics.Conflict.lineHeight

    let title: String
    let label: String
    let lineCount: Int
    let text: String
    let status: Palette.Status

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Metrics.Spacing.xs) {
                Text(title)
                    .font(Metrics.Font.caption.weight(.semibold))
                    .foregroundStyle(status.ink.color)
                if !label.isEmpty {
                    Text(label)
                        .font(Metrics.Font.caption)
                        .foregroundStyle(Palette.Text.secondary.color)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Metrics.Spacing.s)
            .padding(.vertical, Metrics.Spacing.xxs)
            .background(status.tint.color)
            if lineCount == 0 {
                Text("Empty: this side has no lines here.")
                    .font(Metrics.Font.caption.italic())
                    .foregroundStyle(Palette.Text.tertiary.color)
                    .padding(Metrics.Spacing.s)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView([.vertical, .horizontal]) {
                    Text(text)
                        .font(Metrics.Font.monoBody)
                        .foregroundStyle(Palette.Text.primary.color)
                        .lineSpacing(Metrics.Conflict.lineSpacing)
                        .fixedSize()
                        .padding(.horizontal, Metrics.Spacing.s)
                        .padding(.vertical, Metrics.Spacing.xs)
                        .textSelection(.enabled)
                }
                .overlayScrollers()
                .frame(height: min(CGFloat(lineCount) * Self.lineHeight + Metrics.Spacing.s + Metrics.Conflict.lineSpacing, Metrics.Conflict.sideMaximumHeight))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.Surface.window.color)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous).strokeBorder(Palette.Surface.border.color, lineWidth: Metrics.Conflict.border))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(label): \(lineCount == 0 ? "empty" : text)")
    }
}

private struct ConflictResultPane: View {
    let title: String
    let resolver: ConflictResolverViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Metrics.Spacing.m) {
                Text(title)
                    .font(Metrics.Font.body.weight(.semibold))
                    .foregroundStyle(Palette.Text.primary.color)
                if resolver.isResultEditable {
                    Text("Type to edit. ⌘Z undoes.")
                        .font(Metrics.Font.caption)
                        .foregroundStyle(Palette.Text.secondary.color)
                }
                Spacer()
                legend("Ours", fill: Palette.Status.modified.tint, stroke: Palette.Status.modified.ink)
                legend("Theirs", fill: Palette.Status.renamed.tint, stroke: Palette.Status.renamed.ink)
                legend("Edited", fill: Palette.Diff.editedLine, stroke: Palette.Surface.borderStrong)
                legend("Unresolved", fill: Palette.Status.conflict.tint, stroke: Palette.Status.conflict.ink)
            }
            .padding(.horizontal, Metrics.Spacing.m)
            .frame(height: Metrics.Panel.header)
            .background(Palette.Surface.sidebar.color)
            Divider()
            ConflictResultEditor(
                text: resolver.resultText,
                revision: resolver.resultRevision,
                tints: resolver.resultTints,
                documentVersion: resolver.documentVersion,
                isEditable: resolver.isResultEditable && !resolver.isWorking
            ) { text in
                resolver.updateResult(text)
            }
        }
        .background(Palette.Surface.window.color)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("conflict.preview")
    }

    private func legend(_ title: String, fill: ColorToken, stroke: ColorToken) -> some View {
        HStack(spacing: Metrics.Spacing.xs) {
            RoundedRectangle(cornerRadius: Metrics.Radius.badge, style: .continuous)
                .fill(fill.color)
                .overlay(RoundedRectangle(cornerRadius: Metrics.Radius.badge, style: .continuous).strokeBorder(stroke.color, lineWidth: Metrics.Conflict.border))
                .frame(width: Metrics.Conflict.legendSwatch, height: Metrics.Conflict.legendSwatch)
            Text(title).font(Metrics.Font.caption).foregroundStyle(Palette.Text.secondary.color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityIdentifier("conflict.legend.\(title.lowercased())")
    }
}

extension ConflictBlockState {
    var status: String? {
        switch self {
        case .unresolved: nil
        case let .chosen(choice): choice.title
        case .editedByHand: "Edited by hand"
        }
    }
}

extension ConflictChoice {
    var title: String {
        switch self {
        case .ours: "Use Ours"
        case .theirs: "Use Theirs"
        case .oursThenTheirs: "Ours, then Theirs"
        case .theirsThenOurs: "Theirs, then Ours"
        }
    }

    var help: String {
        switch self {
        case .ours: "Keep only our lines for this block"
        case .theirs: "Keep only their lines for this block"
        case .oursThenTheirs: "Keep both: our lines first, then theirs"
        case .theirsThenOurs: "Keep both: their lines first, then ours"
        }
    }
}
