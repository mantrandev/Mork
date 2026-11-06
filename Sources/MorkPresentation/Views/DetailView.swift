import AppKit
import MorkDomain
import SwiftUI

struct DetailView: View {
    let viewModel: RepositoryViewModel
    var showsFileHeaderBar = false
    @Environment(\.diffMetrics) private var metrics
    @State private var pendingDiscard: DiffHunk?
    @State private var pendingLineDiscard = false
    @State private var hunkJump = DiffHunkJump(id: 0, direction: .next)

    var body: some View {
        content
            .morkConfirmation(isPresented: $pendingLineDiscard) {
                let count = viewModel.selectedLineCount
                return MorkConfirmation(
                    kind: .destructive,
                    title: count == 1 ? "Discard the selected line?" : "Discard \(count) selected lines?",
                    message: "The lines go back to their staged version. Git keeps no copy of unstaged edits, so they cannot be recovered.",
                    commands: [DialogCommands.discardPatch(lines: true)],
                    actions: [DialogAction(title: count == 1 ? "Discard Line" : "Discard Lines", isDestructive: true, isDefault: true, identifier: "lines.discard.confirm") { Task { await viewModel.applySelectedLines(.discard) } }],
                    cancelIdentifier: "lines.discard.cancel"
                )
            }
            .morkConfirmation(item: $pendingDiscard) { hunk in
                MorkConfirmation(
                    kind: .destructive,
                    title: "Discard this hunk?",
                    message: "The hunk goes back to its staged version. Git keeps no copy of unstaged edits, so it cannot be recovered.",
                    commands: [DialogCommands.discardPatch(lines: false)],
                    actions: [DialogAction(title: "Discard Changes", isDestructive: true, isDefault: true, identifier: "hunk.discard.confirm") { Task { await viewModel.apply(.discard, to: hunk) } }],
                    cancelIdentifier: "hunk.discard.cancel"
                )
            }
    }

    @ViewBuilder
    private var content: some View {
        if let image = viewModel.imageDiff {
            ImageDiffView(session: image)
        } else {
            textContent
        }
    }

    @ViewBuilder
    private var textContent: some View {
        switch viewModel.detail {
        case .empty:
            EmptyStateView("No File Selected", systemImage: "doc.text", message: "Select a file to see its changes.")
                .accessibilityIdentifier("detail.empty")
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .failed(message):
            EmptyStateView("Could Not Load", systemImage: "exclamationmark.triangle", message: message)
        case let .loaded(text):
            if text.isEmpty {
                EmptyStateView("No Differences", systemImage: "equal")
                    .accessibilityIdentifier("detail.noDiff")
            } else if let summary = viewModel.submodulePointerSummary {
                SubmodulePointerView(summary: summary)
            } else if let pointer = viewModel.advanced.lfsPointer {
                LFSPointerView(change: pointer)
            } else if let document = viewModel.diffDocument {
                if document.isCollapsed {
                    LargeDiffPlaceholder(lineCount: document.totalLines, show: viewModel.showLargeDiff)
                } else if case .commit = viewModel.selection, !document.hasFileHeader {
                    EmptyStateView("No File Selected", systemImage: "doc.text", message: "Select a changed file to see its diff.")
                        .accessibilityIdentifier("detail.empty")
                } else if showsFileHeaderBar, case .commitFile = viewModel.selection, case let .file(header, meta, additions, deletions)? = document.blocks.first {
                    VStack(spacing: 0) {
                        DiffFileHeaderBar(
                            summary: DiffFileSummary(header: ([header] + meta).map(\.text), additions: additions, deletions: deletions),
                            rawLines: ([header] + meta).map(\.text),
                            showsRaw: viewModel.showsRawDiff,
                            toggleRaw: { viewModel.showsRawDiff.toggle() },
                            jump: { direction in hunkJump = DiffHunkJump(id: hunkJump.id + 1, direction: direction) },
                            options: viewModel.settings.diff,
                            changeOptions: { viewModel.changeDiffSettings($0) }
                        )
                        Hairline()
                        if viewModel.settings.diff.showsSideBySide {
                            SplitDiffTableView(document: document, metrics: metrics)
                                .accessibilityIdentifier("detail.sideBySide")
                        } else {
                            DiffText(document: document, menuModel: viewModel, hidesFileCards: true, hunkJump: hunkJump)
                        }
                    }
                } else if let patch = viewModel.patch, !viewModel.hunkActions.isEmpty {
                    DiffText(
                        document: document,
                        hunks: patch.hunks,
                        actions: viewModel.hunkActions,
                        perform: perform,
                        lineModel: viewModel,
                        performLines: performLines,
                        showsRawDiff: viewModel.showsRawDiff,
                        toggleRawDiff: { viewModel.showsRawDiff.toggle() },
                        menuModel: viewModel
                    )
                } else {
                    DiffText(document: document, showsRawDiff: viewModel.showsRawDiff, toggleRawDiff: { viewModel.showsRawDiff.toggle() }, menuModel: viewModel)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func performLines(_ action: HunkAction) {
        if action == .discard, viewModel.confirmsDestructiveActions {
            pendingLineDiscard = true
        } else {
            Task { await viewModel.applySelectedLines(action) }
        }
    }

    private func perform(_ action: HunkAction, on hunk: DiffHunk) {
        if action == .discard, viewModel.confirmsDestructiveActions {
            pendingDiscard = hunk
        } else {
            Task { await viewModel.apply(action, to: hunk) }
        }
    }
}

struct LargeDiffPlaceholder: View {
    let lineCount: Int
    let show: () -> Void

    var body: some View {
        EmptyStateView("Large Diff", systemImage: "doc.text.magnifyingglass", message: "This diff has \(lineCount.formatted()) lines. It is hidden to keep the app responsive.") {
            Button("Show Anyway", action: show)
                .buttonStyle(.morkSecondary)
                .accessibilityIdentifier("diff.showLarge")
        }
        .accessibilityIdentifier("diff.large")
    }
}

struct DiffText: View {
    let document: DiffDocument
    var hunks: [DiffHunk] = []
    var actions: [HunkAction] = []
    var perform: (HunkAction, DiffHunk) -> Void = { _, _ in }
    var lineModel: RepositoryViewModel? = nil
    var performLines: (HunkAction) -> Void = { _ in }
    var showsRawDiff = false
    var toggleRawDiff: (() -> Void)? = nil
    var menuModel: RepositoryViewModel? = nil
    var hidesFileCards = false
    var hunkJump: DiffHunkJump? = nil
    @Environment(\.diffMetrics) private var metrics

    var body: some View {
        DiffTableView(
            document: document,
            metrics: metrics,
            hunks: hunks,
            actions: actions,
            perform: perform,
            lineModel: lineModel,
            performLines: performLines,
            lineState: DiffLineState(
                selection: lineModel?.lineSelection ?? DiffLineSelection(),
                hasChanges: lineModel?.lineSelectionHasChanges ?? false,
                isBusy: lineModel?.isBusy ?? false
            ),
            showsRawDiff: showsRawDiff,
            toggleRawDiff: toggleRawDiff,
            menuModel: menuModel,
            hidesFileCards: hidesFileCards,
            hunkJump: hunkJump
        )
        .background(Palette.Surface.window.color)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("detail.diff")
    }
}

struct DiffFileCard: View {
    let header: DiffLine
    let meta: [DiffLine]
    let additions: Int
    let deletions: Int
    let showsRaw: Bool
    let toggleRaw: (() -> Void)?

    var body: some View {
        let summary = DiffFileSummary(header: ([header] + meta).map(\.text), additions: additions, deletions: deletions)
        VStack(alignment: .leading, spacing: Metrics.Spacing.xs) {
            HStack(spacing: Metrics.Spacing.s - 2) {
                FileIcon(path: summary.path)
                FilePathText(path: summary.path, originalPath: summary.oldPath)
                    .font(Metrics.Font.title)
                DiffStatusTag(summary: summary)
                Spacer(minLength: Metrics.Spacing.s)
                DiffCounts(additions: additions, deletions: deletions)
                if let toggleRaw {
                    Button(showsRaw ? "Hide raw diff" : "Show raw diff", action: toggleRaw)
                        .buttonStyle(.mork(.link, size: .small))
                        .help("Show the diff --git, index, --- and +++ lines exactly as git prints them")
                        .accessibilityIdentifier("diff.rawToggle")
                }
            }
            if let detail = Self.detail(of: summary) {
                Text(detail)
                    .font(Metrics.Font.monoCaption)
                    .foregroundStyle(Palette.Text.secondary.color)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityIdentifier("diff.detail.\(summary.path)")
            }
            if showsRaw {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach([header] + meta) { line in
                        Text(line.text)
                            .font(Metrics.Font.monoCaption)
                            .foregroundStyle(Palette.Text.secondary.color)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("diff.raw.\(summary.path)")
            }
        }
        .padding(.horizontal, Metrics.Spacing.m)
        .padding(.vertical, Metrics.Spacing.s)
        .background(Palette.Surface.raised.color, in: RoundedRectangle(cornerRadius: Metrics.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metrics.Radius.card, style: .continuous).strokeBorder(Palette.Surface.border.color, lineWidth: Metrics.Line.hairline))
        .padding(.horizontal, Metrics.Spacing.s)
        .padding(.top, Metrics.Spacing.s)
        .padding(.bottom, Metrics.Spacing.xs)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("diff.file.\(summary.path)")
    }

    static func detail(of summary: DiffFileSummary) -> String? {
        var parts: [String] = []
        if let oldPath = summary.oldPath, summary.status == .renamed || summary.status == .copied {
            parts.append("\(summary.status == .copied ? "copied" : "renamed") from \(oldPath)")
        }
        if summary.hasModeChange, let oldMode = summary.oldMode, let newMode = summary.newMode {
            parts.append("mode \(oldMode) → \(newMode)")
        } else if summary.status == .added, let newMode = summary.newMode, newMode != "100644" {
            parts.append("mode \(newMode)")
        }
        if summary.isBinary { parts.append("binary file") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

struct DiffViewOptions: View {
    let options: DiffSettings
    let change: ((inout DiffSettings) -> Void) -> Void

    var body: some View {
        let range = DiffSettings.contextLineRange
        DiffBarButton(systemImage: "paragraphsign", help: options.showsWhitespaceChanges ? "Hide Whitespace Changes" : "Show Whitespace Changes", identifier: "diff.whitespace", isOn: options.showsWhitespaceChanges) {
            change { $0.showsWhitespaceChanges.toggle() }
        }
        DiffBarButton(systemImage: "arrow.down.right.and.arrow.up.left", help: "Fewer Context Lines (\(options.contextLines))", identifier: "diff.fewerContext") {
            change { $0.contextLines -= 1 }
        }
        .disabled(options.contextLines <= range.lowerBound)
        DiffBarButton(systemImage: "arrow.up.left.and.arrow.down.right", help: "More Context Lines (\(options.contextLines))", identifier: "diff.moreContext") {
            change { $0.contextLines += 1 }
        }
        .disabled(options.contextLines >= range.upperBound)
        DiffBarButton(systemImage: "rectangle.split.2x1", help: options.showsSideBySide ? "Show Inline Diff" : "Show Side by Side", identifier: "diff.sideBySide", isOn: options.showsSideBySide) {
            change { $0.showsSideBySide.toggle() }
        }
    }
}

struct DiffFileHeaderBar: View {
    let summary: DiffFileSummary
    let rawLines: [String]
    let showsRaw: Bool
    let toggleRaw: () -> Void
    let jump: (DiffHunkJump.Direction) -> Void
    let options: DiffSettings
    let changeOptions: ((inout DiffSettings) -> Void) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Metrics.Spacing.xs) {
                DiffBarButton(systemImage: "chevron.up", help: "Previous Hunk", identifier: "diff.previousHunk") { jump(.previous) }
                DiffBarButton(systemImage: "chevron.down", help: "Next Hunk", identifier: "diff.nextHunk") { jump(.next) }
                FileIcon(path: summary.path)
                    .padding(.leading, Metrics.Spacing.xs)
                PathLabel(path: summary.path, font: .systemFont(ofSize: Metrics.FontSize.body))
                    .layoutPriority(-1)
                DiffStatusTag(summary: summary)
                Spacer(minLength: Metrics.Spacing.s)
                DiffCounts(additions: summary.additions, deletions: summary.deletions)
                DiffViewOptions(options: options, change: changeOptions)
                DiffBarButton(systemImage: "doc.plaintext", help: showsRaw ? "Hide Raw Diff Header" : "Show Raw Diff Header", identifier: "diff.rawToggle", isOn: showsRaw, action: toggleRaw)
            }
            .padding(.horizontal, Metrics.Spacing.s)
            .frame(height: Metrics.CommitDetails.diffHeaderHeight)
            if let detail = DiffFileCard.detail(of: summary) {
                Text(detail)
                    .font(Metrics.Font.monoCaption)
                    .foregroundStyle(Palette.Text.secondary.color)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, Metrics.Spacing.m)
                    .padding(.bottom, Metrics.Spacing.xs)
                    .accessibilityIdentifier("diff.detail.\(summary.path)")
            }
            if showsRaw {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(rawLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(Metrics.Font.monoCaption)
                            .foregroundStyle(Palette.Text.secondary.color)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .padding(.horizontal, Metrics.Spacing.m)
                .padding(.bottom, Metrics.Spacing.xs)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("diff.raw.\(summary.path)")
            }
        }
        .background(Palette.Surface.window.color)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("diff.file.\(summary.path)")
    }
}

struct DiffBarButton: View {
    let systemImage: String
    let help: String
    let identifier: String
    var isOn = false
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: Metrics.Icon.small, weight: .medium))
                .foregroundStyle(!isEnabled ? Palette.Text.tertiary.color : isOn ? Palette.Accent.text.color : Palette.Text.secondary.color)
                .frame(width: Metrics.HitTarget.inline, height: Metrics.HitTarget.inline)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .accessibilityIdentifier(identifier)
    }
}

struct DiffCounts: View {
    let additions: Int
    let deletions: Int

    var body: some View {
        HStack(spacing: Metrics.Spacing.xs) {
            if additions > 0 {
                Text("+\(additions)")
                    .foregroundStyle(Palette.Status.added.ink.color)
            }
            if deletions > 0 {
                Text("−\(deletions)")
                    .foregroundStyle(Palette.Status.deleted.ink.color)
            }
        }
        .font(Metrics.Font.monoCaption.weight(.semibold))
    }
}

private struct DiffStatusTag: View {
    let summary: DiffFileSummary

    var body: some View {
        if let title {
            let status = Palette.Status.status(for: summary.status)
            Text(title)
                .font(Metrics.Font.label)
                .padding(.horizontal, Metrics.Badge.padding)
                .frame(height: Metrics.Control.badge)
                .foregroundStyle(status.ink.color)
                .background(status.tint.color, in: RoundedRectangle(cornerRadius: Metrics.Radius.badge, style: .continuous))
                .accessibilityIdentifier("diff.status.\(summary.path)")
        }
    }

    private var title: String? {
        if summary.status != .modified { return summary.status.title }
        return summary.hasModeChange ? "Mode Changed" : nil
    }
}

extension Palette.Status {
    static func status(for status: DiffFileStatus) -> Palette.Status {
        switch status {
        case .added: .added
        case .deleted: .deleted
        case .renamed, .copied: .renamed
        case .modified: .modified
        }
    }
}
