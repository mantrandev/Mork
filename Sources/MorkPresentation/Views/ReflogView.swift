import AppKit
import MorkDomain
import SwiftUI

struct ReflogView: View {
    @Bindable var viewModel: RepositoryViewModel
    @State private var selected: ReflogEntry.ID?
    @State private var branchTarget: Commit?

    var body: some View {
        content
            .task { await viewModel.loadReflog() }
            .sheet(item: $branchTarget) { commit in
                BranchAtCommitSheet(commit: commit, branchNames: viewModel.localBranches.map(\.name)) { name, checkout in
                    Task { await viewModel.createBranch(named: name, at: commit, checkout: checkout) }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.reflog {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .failed(message):
            EmptyStateView("Could Not Load Reflog", systemImage: "exclamationmark.triangle", message: message)
        case let .loaded(entries) where entries.isEmpty:
            EmptyStateView("Reflog Is Empty", systemImage: "arrow.uturn.backward.circle", message: "HEAD has not moved yet.")
                .accessibilityIdentifier("reflog.empty")
        case let .loaded(entries):
            VStack(spacing: 0) {
                Label("git reflog lists every move of HEAD. A commit lost after reset --hard or a rebase is still here: right-click it and create a branch to rescue it.", systemImage: "lightbulb")
                    .font(Metrics.Font.caption)
                    .foregroundStyle(Palette.Text.secondary.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Metrics.Spacing.m)
                    .padding(.vertical, Metrics.Spacing.s)
                    .accessibilityIdentifier("reflog.help")
                Hairline()
                List(selection: Binding(get: { selected }, set: { id in
                    selected = id
                    if let entry = entries.first(where: { $0.id == id }) { viewModel.select(entry) }
                })) {
                    ForEach(entries) { entry in
                        ReflogRow(entry: entry)
                            .tag(entry.id)
                            .contextMenu {
                                Button("Create Branch Here…") { branchTarget = entry.commit }
                                    .accessibilityIdentifier("reflog.createBranch")
                                Button("Copy SHA") { copy(entry.commit.hash) }
                                    .accessibilityIdentifier("reflog.copySHA")
                            }
                    }
                }
                .listStyle(.plain)
                .environment(\.defaultMinListRowHeight, Metrics.Row.history)
                .accessibilityIdentifier("reflog.list")
            }
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

private struct ReflogRow: View {
    let entry: ReflogEntry

    var body: some View {
        HStack(spacing: Metrics.Spacing.s) {
            Text(entry.selector)
                .font(Metrics.Font.monoCaption)
                .foregroundStyle(Palette.Text.secondary.color)
                .frame(minWidth: Metrics.Reflog.selectorWidth, alignment: .leading)
            Text(entry.action)
                .font(Metrics.Font.caption.weight(.semibold))
                .foregroundStyle(Palette.Accent.text.color)
                .padding(.horizontal, Metrics.Badge.padding)
                .frame(height: Metrics.Control.badge)
                .background(Palette.Accent.tint.color, in: RoundedRectangle(cornerRadius: Metrics.Radius.badge, style: .continuous))
            Text(entry.message)
                .foregroundStyle(Palette.Text.primary.color)
                .lineLimit(1)
            Spacer(minLength: Metrics.Spacing.s)
            Text(entry.date, format: .relative(presentation: .numeric))
                .font(Metrics.Font.caption.monospacedDigit())
                .foregroundStyle(Palette.Text.secondary.color)
                .lineLimit(1)
            Text(entry.commit.shortHash)
                .font(Metrics.Font.monoCaption)
                .foregroundStyle(Palette.Text.secondary.color)
        }
        .font(Metrics.Font.body)
        .frame(height: Metrics.Row.history)
        .help(entry.commit.subject)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("reflog.\(entry.selector)")
    }
}
