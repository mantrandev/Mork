import MorkDomain
import SwiftUI

struct MergeFoldButton: View {
    enum Style {
        case node
        case badge
    }

    let commit: Commit
    let fold: MergeFold
    let lane: Int
    let style: Style
    let viewModel: RepositoryViewModel
    @State private var state = RefBadgePopoverState()
    @State private var timer: Task<Void, Never>?
    @State private var merged: [Commit] = []

    var body: some View {
        Button {
            timer?.cancel()
            state.dismiss()
            Task { await viewModel.toggleMergeCollapse(commit) }
        } label: {
            label
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .onHover { inside in
            state.hoverBadge(inside)
            schedule(entering: inside)
        }
        .popover(isPresented: Binding(get: { state.isPresented }, set: { if !$0 { state.dismiss() } }), arrowEdge: .bottom) {
            MergePreviewList(merge: commit, commits: merged, isCollapsed: fold.isCollapsed)
                .onHover { inside in
                    state.hoverPopover(inside)
                    schedule(entering: inside)
                }
        }
        .accessibilityLabel(fold.isCollapsed ? "Expand merged commits" : "Collapse merged commits")
        .accessibilityIdentifier("history.mergeFold.\(style == .node ? "node" : "badge").\(commit.shortHash)")
    }

    @ViewBuilder
    private var label: some View {
        switch style {
        case .node:
            Color.clear
                .frame(width: Metrics.HitTarget.inline, height: Metrics.HitTarget.inline)
        case .badge:
            let color = CommitGraphGeometry.color(lane)
            HStack(spacing: Metrics.Spacing.xxs) {
                Image(systemName: "chevron.right")
                    .font(Metrics.Font.label)
                Text(fold.hiddenCount == 1 ? "1 commit" : "\(fold.hiddenCount) commits")
                    .font(Metrics.Font.caption)
            }
            .foregroundStyle(color)
            .padding(.horizontal, Metrics.Badge.padding)
            .frame(height: Metrics.Badge.height)
            .overlay(RoundedRectangle(cornerRadius: Metrics.Radius.badge).strokeBorder(color, style: StrokeStyle(lineWidth: Metrics.Badge.borderWidth, dash: Metrics.Line.dash)))
        }
    }

    private func schedule(entering: Bool) {
        timer?.cancel()
        timer = Task { @MainActor in
            try? await Task.sleep(for: entering ? RefBadgePopover.openDelay : RefBadgePopover.closeDelay)
            guard !Task.isCancelled else { return }
            if state.shouldOpen {
                merged = viewModel.mergedCommits(of: commit)
                state.open()
            } else if state.isPresented, state.shouldClose {
                state.close()
            }
        }
    }
}

private struct MergePreviewList: View {
    let merge: Commit
    let commits: [Commit]
    let isCollapsed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(commits.count == 1 ? "1 commit merged" : "\(commits.count) commits merged")
                .font(Metrics.Font.label)
                .foregroundStyle(Palette.Text.secondary.color)
                .padding(.horizontal, Metrics.Spacing.s)
                .padding(.vertical, Metrics.Spacing.xs)
            if commits.isEmpty {
                Text("None of them are loaded in the history yet.")
                    .font(Metrics.Font.body)
                    .foregroundStyle(Palette.Text.secondary.color)
                    .padding(.horizontal, Metrics.Spacing.s)
                    .padding(.bottom, Metrics.Spacing.s)
            } else {
                List(commits) { commit in
                    HStack(spacing: Metrics.Spacing.s) {
                        Text(commit.shortHash)
                            .font(Metrics.Font.monoCaption)
                            .foregroundStyle(Palette.Text.secondary.color)
                            .frame(width: Metrics.MergePreview.hashWidth, alignment: .leading)
                        Text(commit.subject)
                            .font(Metrics.Font.body)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: Metrics.Spacing.s)
                        Text(commit.author)
                            .font(Metrics.Font.caption)
                            .foregroundStyle(Palette.Text.secondary.color)
                            .lineLimit(1)
                    }
                    .frame(height: Metrics.Row.list)
                    .listRowInsets(Metrics.listRowInsets)
                }
                .listStyle(.plain)
                .environment(\.defaultMinListRowHeight, Metrics.Row.list)
                .frame(height: min(CGFloat(commits.count) * Metrics.Row.list + Metrics.Spacing.s, Metrics.MergePreview.maxHeight))
            }
            VStack(alignment: .leading, spacing: Metrics.Spacing.xxs) {
                Text(isCollapsed ? "Click to show them again." : "Click the merge dot to hide them.")
                    .font(Metrics.Font.caption)
                    .foregroundStyle(Palette.Text.secondary.color)
                Text("git log --oneline \(merge.shortHash)^1..\(merge.shortHash)")
                    .font(Metrics.Font.monoCaption)
                    .foregroundStyle(Palette.Text.tertiary.color)
                    .textSelection(.enabled)
            }
            .padding(Metrics.Spacing.s)
        }
        .frame(width: Metrics.MergePreview.width, alignment: .leading)
        .accessibilityIdentifier("history.mergePreview")
    }
}
