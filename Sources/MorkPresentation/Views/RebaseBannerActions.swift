import SwiftUI

struct RebaseBannerActions: View {
    let viewModel: RepositoryViewModel

    var body: some View {
        Button("Continue") { Task { await viewModel.continueRebase() } }
            .buttonStyle(.morkPrimary)
            .help("git rebase --continue")
            .disabled(viewModel.hasConflicts)
            .accessibilityIdentifier("banner.continueRebase")
        Button("Skip") { Task { await viewModel.skipRebase() } }
            .buttonStyle(.morkSecondary)
            .help("git rebase --skip")
            .accessibilityIdentifier("banner.skipRebase")
        Button("Abort") { Task { await viewModel.abortRebase() } }
            .buttonStyle(.morkDestructive)
            .help("git rebase --abort")
            .accessibilityIdentifier("banner.abortRebase")
    }
}
