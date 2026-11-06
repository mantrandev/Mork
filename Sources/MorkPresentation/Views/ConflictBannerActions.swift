import SwiftUI

struct ConflictBannerActions: View {
    let viewModel: RepositoryViewModel

    var body: some View {
        Label(viewModel.conflictSummary, systemImage: viewModel.hasConflicts ? "exclamationmark.circle" : "checkmark.circle.fill")
            .font(Metrics.Font.body.weight(.medium))
            .foregroundStyle(viewModel.hasConflicts ? Palette.Text.primary.color : Palette.Status.added.ink.color)
            .accessibilityIdentifier("banner.conflicts")
        if viewModel.canConcludeMerge {
            Button("Commit Merge") { Task { await viewModel.concludeMerge() } }
                .buttonStyle(.morkPrimary)
                .help("git commit --no-edit")
                .accessibilityIdentifier("banner.commitMerge")
        }
    }
}
