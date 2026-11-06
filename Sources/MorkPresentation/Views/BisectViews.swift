import MorkDomain
import SwiftUI

struct BisectBanner: View {
    let viewModel: RepositoryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.xs + Metrics.Spacing.xxs) {
            HStack(spacing: Metrics.Spacing.s) {
                Image(systemName: "scope")
                    .foregroundStyle(Palette.Accent.text.color)
                Text(viewModel.bisectSummary)
                    .font(Metrics.Font.body.weight(.medium))
                    .foregroundStyle(Palette.Text.primary.color)
                    .accessibilityIdentifier("bisect.summary")
                Spacer()
                if viewModel.canMarkBisect {
                    Button("Good") { Task { await viewModel.markBisect(.good) } }
                        .buttonStyle(.mork(.secondary, size: .small))
                        .help("git bisect good: the checked-out commit does not have the bug")
                        .accessibilityIdentifier("bisect.good")
                    Button("Bad") { Task { await viewModel.markBisect(.bad) } }
                        .buttonStyle(.mork(.secondary, size: .small))
                        .help("git bisect bad: the checked-out commit has the bug")
                        .accessibilityIdentifier("bisect.bad")
                    Button("Skip") { Task { await viewModel.markBisect(.skip) } }
                        .buttonStyle(.mork(.secondary, size: .small))
                        .help("git bisect skip: the checked-out commit cannot be tested")
                        .disabled(!viewModel.canSkipBisect)
                        .accessibilityIdentifier("bisect.skip")
                }
                Button("Show Log") { Task { await viewModel.showBisectLog() } }
                    .buttonStyle(.mork(.secondary, size: .small))
                    .help("git bisect log")
                    .accessibilityIdentifier("bisect.showLog")
                Button("Reset") { Task { await viewModel.resetBisect() } }
                    .buttonStyle(.mork(.secondary, size: .small))
                    .help("git bisect reset: end the bisect and go back to the branch you started from")
                    .accessibilityIdentifier("bisect.reset")
            }
            if let hint = viewModel.bisectHint {
                Text(hint)
                    .font(Metrics.Font.caption)
                    .foregroundStyle(Palette.Text.secondary.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("bisect.hint")
            }
            if let result = viewModel.bisectResult {
                BisectResultCard(viewModel: viewModel, result: result)
            }
        }
        .padding(.horizontal, Metrics.Spacing.m)
        .padding(.vertical, Metrics.Spacing.s)
        .background(Palette.Accent.tint.color)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("bisect.banner")
    }
}

private struct BisectResultCard: View {
    let viewModel: RepositoryViewModel
    let result: BisectCommit

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.Spacing.s + Metrics.Spacing.xxs) {
            Image(systemName: "ladybug.fill")
                .font(Metrics.Font.heading)
                .foregroundStyle(Palette.Status.deleted.ink.color)
            VStack(alignment: .leading, spacing: Metrics.Spacing.xxs) {
                Text("First bad commit")
                    .font(Metrics.Font.label)
                    .tracking(Metrics.Font.labelTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.Text.secondary.color)
                HStack(spacing: Metrics.Spacing.xs + Metrics.Spacing.xxs) {
                    Text(result.shortHash)
                        .font(Metrics.Font.monoCaption)
                        .foregroundStyle(Palette.Text.secondary.color)
                    Text(result.subject)
                        .font(Metrics.Font.title.weight(.semibold))
                        .foregroundStyle(Palette.Text.primary.color)
                        .lineLimit(1)
                }
                Text("Found with \(viewModel.bisectSession?.entries.count ?? 0) answers. Reset to go back to \(viewModel.bisectSession?.originalHead ?? "your branch").")
                    .font(Metrics.Font.caption)
                    .foregroundStyle(Palette.Text.secondary.color)
            }
            Spacer()
            Button("Show in History") { Task { await viewModel.showBisectResult(result) } }
                .buttonStyle(.mork(.secondary, size: .small))
                .accessibilityIdentifier("bisect.result.show")
            Button("Reset") { Task { await viewModel.resetBisect() } }
                .buttonStyle(.mork(.primary, size: .small))
                .help("git bisect reset")
                .accessibilityIdentifier("bisect.result.reset")
        }
        .padding(Metrics.Spacing.s + Metrics.Spacing.xxs)
        .background(Palette.Surface.window.color, in: RoundedRectangle(cornerRadius: Metrics.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metrics.Radius.card, style: .continuous).strokeBorder(Palette.Status.deleted.ink.color, lineWidth: Metrics.Line.hairline))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("First bad commit \(result.shortHash) \(result.subject)")
        .accessibilityIdentifier("bisect.result")
    }
}

struct BisectBadge: View {
    let kind: BisectBadgeKind

    var body: some View {
        Label(title, systemImage: icon)
            .labelStyle(.titleAndIcon)
            .font(Metrics.Font.caption.weight(.medium))
            .lineLimit(1)
            .foregroundStyle(kind == .firstBad ? Palette.Status.onFill.color : ink.color)
            .padding(.horizontal, Metrics.Badge.padding)
            .frame(height: Metrics.Control.badge)
            .background(kind == .firstBad ? ink.color : tint.color, in: RoundedRectangle(cornerRadius: Metrics.Radius.badge, style: .continuous))
            .help(help)
            .accessibilityLabel("Bisect: \(title)")
    }

    private var title: String {
        switch kind {
        case .good: "good"
        case .bad: "bad"
        case .skip: "skip"
        case .candidate: "testing"
        case .firstBad: "first bad"
        }
    }

    private var icon: String {
        switch kind {
        case .good: "checkmark"
        case .bad: "xmark"
        case .skip: "forward"
        case .candidate: "scope"
        case .firstBad: "ladybug.fill"
        }
    }

    private var ink: ColorToken { Self.status(for: kind).ink }
    private var tint: ColorToken { Self.status(for: kind).tint }

    static func status(for kind: BisectBadgeKind) -> Palette.Status {
        switch kind {
        case .good: .added
        case .bad, .firstBad: .deleted
        case .skip: .untracked
        case .candidate: Palette.Status(ink: Palette.Accent.text, tint: Palette.Accent.tint)
        }
    }

    private var help: String {
        switch kind {
        case .good: "Marked good: the bug is not in this commit"
        case .bad: "Marked bad: the bug is in this commit"
        case .skip: "Skipped: this commit could not be tested"
        case .candidate: "Checked out by git bisect: test this commit"
        case .firstBad: "git bisect found the bug was introduced here"
        }
    }
}

struct BisectMenuItems: View {
    let viewModel: RepositoryViewModel
    let commit: Commit

    var body: some View {
        Button("Bisect: Mark as Bad") { Task { await viewModel.markBisect(.bad, commit: commit) } }
            .disabled(viewModel.isBisecting && !viewModel.canMarkBisect)
            .accessibilityIdentifier("history.bisectBad")
        Button("Bisect: Mark as Good") { Task { await viewModel.markBisect(.good, commit: commit) } }
            .disabled(viewModel.isBisecting && !viewModel.canMarkBisect)
            .accessibilityIdentifier("history.bisectGood")
        if viewModel.isBisecting {
            Button("Bisect: Skip") { Task { await viewModel.markBisect(.skip, commit: commit) } }
                .disabled(!viewModel.canMarkBisect)
                .accessibilityIdentifier("history.bisectSkip")
        }
    }
}

struct BisectMenu: View {
    let repository: RepositoryViewModel?

    var body: some View {
        Menu("Bisect") {
            Button("Start") { run { await $0.startBisect() } }
                .disabled(repository == nil || repository?.isBisecting == true)
            Divider()
            Button("Mark Current as Good") { run { await $0.markBisect(.good) } }
                .disabled(!(repository?.canMarkBisect ?? false))
            Button("Mark Current as Bad") { run { await $0.markBisect(.bad) } }
                .disabled(!(repository?.canMarkBisect ?? false))
            Button("Skip Current") { run { await $0.markBisect(.skip) } }
                .disabled(!(repository?.canSkipBisect ?? false))
            Divider()
            Button("Show Log") { run { await $0.showBisectLog() } }
                .disabled(!(repository?.isBisecting ?? false))
            Button("Reset") { run { await $0.resetBisect() } }
                .disabled(!(repository?.isBisecting ?? false))
        }
        .disabled(repository == nil)
    }

    private func run(_ action: @escaping @MainActor (RepositoryViewModel) async -> Void) {
        guard let repository else { return }
        Task { await action(repository) }
    }
}

struct BisectLogSheet: View {
    let log: BisectLogText
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        DialogScaffold(
            kind: .notice,
            glyph: "list.bullet.rectangle",
            title: "Bisect Log",
            message: "Every answer so far. Lines starting with # are notes; the others replay the session with git bisect replay.",
            width: Metrics.Sheet.wideWidth
        ) {
            CommandStrip(command: DialogCommands.bisectLog)
            ScrollView {
                Text(log.text)
                    .font(Metrics.Font.monoCaption)
                    .foregroundStyle(Palette.Text.primary.color)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Metrics.Sheet.commandStripInset)
                    .accessibilityIdentifier("bisectLog.text")
            }
            .frame(height: Metrics.Bisect.logMinimumHeight)
            .background(Palette.Surface.well.color)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous))
        } buttons: {
            DialogConfirmButton(title: "Done", identifier: "bisectLog.done") { dismiss() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("bisectLog.sheet")
    }
}
