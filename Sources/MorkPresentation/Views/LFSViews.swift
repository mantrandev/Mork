import MorkDomain
import SwiftUI

struct LFSMenu: View {
    let repository: RepositoryViewModel?

    var body: some View {
        Menu("Git LFS") {
            switch repository?.lfsInstallation {
            case nil:
                Button("Checking for Git LFS…") { run { await $0.detectLFS() } }
                    .disabled(true)
            case .notInstalled:
                Button("Git LFS Is Not Installed…") { run { await $0.showLFSInstallHint() } }
            case .installed:
                Button("Initialize") { run { await $0.initializeLFS() } }
                Divider()
                Button("Track Pattern…") { repository?.requestLFSTrack() }
                Button("Untrack Pattern…") { run { await $0.requestLFSUntrack() } }
                Divider()
                Button("Fetch LFS Objects") { repository?.requestLFSTransfer(.fetch) }
                Button("Pull LFS Objects") { repository?.requestLFSTransfer(.pull) }
            }
        }
        .disabled(repository == nil)
    }

    private func run(_ action: @escaping @MainActor (RepositoryViewModel) async -> Void) {
        guard let repository else { return }
        Task { await action(repository) }
    }
}

struct LFSFileMenu: View {
    let viewModel: RepositoryViewModel
    let path: String

    var body: some View {
        if viewModel.isLFSInstalled, !viewModel.isLFSFile(path) {
            Divider()
            Button("Track \(viewModel.lfsPattern(forFile: path)) with Git LFS") { Task { await viewModel.trackFileTypeWithLFS(path) } }
                .accessibilityIdentifier("lfs.trackFileType.\(path)")
        }
    }
}

struct LFSBadge: View {
    let path: String

    var body: some View {
        Text("LFS")
            .font(Metrics.Font.label)
            .foregroundStyle(Palette.Text.secondary.color)
            .padding(.horizontal, Metrics.Spacing.xs)
            .frame(height: Metrics.LineHeight.caption)
            .overlay(RoundedRectangle(cornerRadius: Metrics.Radius.badge).strokeBorder(Palette.Surface.borderStrong.color))
            .help("Stored with Git LFS (filter=lfs in .gitattributes)")
            .accessibilityLabel("Git LFS")
            .accessibilityIdentifier("lfsBadge.\(path)")
    }
}

struct LFSPointerView: View {
    let change: LFSPointerChange

    var body: some View {
        VStack(spacing: Metrics.Spacing.m) {
            Image(systemName: "externaldrive.badge.icloud")
                .font(.system(size: Metrics.Icon.avatar))
                .foregroundStyle(Palette.Text.secondary.color)
            Text(change.summary)
                .font(Metrics.Font.heading)
                .foregroundStyle(Palette.Text.primary.color)
                .textSelection(.enabled)
                .accessibilityIdentifier("detail.lfsPointer")
            if let oid = change.new?.oid ?? change.old?.oid {
                Text(oid)
                    .font(Metrics.Font.monoCaption)
                    .foregroundStyle(Palette.Text.secondary.color)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Text("Git LFS keeps this file outside the repository. Git only stores a small pointer with the file's sha256 and size, so Mork shows the object instead of a text diff.")
                .font(Metrics.Font.body)
                .foregroundStyle(Palette.Text.secondary.color)
                .multilineTextAlignment(.center)
                .frame(maxWidth: Metrics.Sheet.width)
        }
        .padding(Metrics.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LFSUntrackSheet: View {
    let viewModel: RepositoryViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        DialogScaffold(
            kind: .form,
            glyph: "externaldrive.badge.minus",
            title: "Untrack Git LFS Pattern"
        ) {
            patterns
                .frame(height: Metrics.Panel.minimumHeight)
                .background(Palette.Surface.well.color)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous))
            CommandStrip(command: DialogCommands.lfsUntrack("<pattern>"), note: "runs on Untrack")
        } buttons: {
            DialogConfirmButton(title: "Done", identifier: "lfs.untrack.done") { dismiss() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lfs.untrackSheet")
    }

    @ViewBuilder
    private var patterns: some View {
        switch viewModel.advanced.lfsPatterns {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .failed(message):
            EmptyStateView("Could Not List Patterns", systemImage: "exclamationmark.triangle", message: message)
        case let .loaded(patterns) where patterns.isEmpty:
            EmptyStateView("No Tracked Patterns", systemImage: "externaldrive", message: "git lfs track lists nothing in .gitattributes.")
                .accessibilityIdentifier("lfs.untrack.empty")
        case let .loaded(patterns):
            List(patterns, id: \.self) { pattern in
                HStack {
                    Text(pattern).font(Metrics.Font.monoBody).foregroundStyle(Palette.Text.primary.color).lineLimit(1)
                    Spacer()
                    Button("Untrack") { Task { await viewModel.untrackLFS(pattern: pattern) } }
                        .buttonStyle(.mork(.destructive, size: .small))
                        .help(DialogCommands.lfsUntrack(pattern))
                        .accessibilityIdentifier("lfs.untrack.\(pattern)")
                }
                .frame(height: Metrics.Row.list)
            }
            .scrollContentBackground(.hidden)
            .accessibilityIdentifier("lfs.untrack.list")
        }
    }
}

struct LFSTransferSheet: View {
    let viewModel: RepositoryViewModel
    let transfer: LFSTransfer
    @Environment(\.dismiss) private var dismiss

    private var state: LFSTransferState { viewModel.advanced.lfsTransfer }

    var body: some View {
        DialogScaffold(
            kind: state.failure == nil ? .notice : .error,
            glyph: state.failure == nil ? (transfer == .fetch ? "arrow.down.circle" : "arrow.down.doc") : nil,
            title: transfer == .fetch ? "Fetch LFS Objects" : "Pull LFS Objects",
            message: transfer == .fetch ? "Downloads the LFS objects of the current branch into .git/lfs. The files in the folder stay pointers." : "Downloads the LFS objects of the current branch and replaces the pointers in the folder with the real files.",
            width: Metrics.Sheet.wideWidth
        ) {
            if state.isRunning {
                DialogProgressBar(fraction: state.progress.percent.map { Double($0) / 100 })
            }
            CommandStrip(command: DialogCommands.lfsTransfer(transfer))
            LogLinesList(lines: state.progress.lines)
                .frame(height: Metrics.Panel.minimumHeight - Metrics.Spacing.xl)
                .background(Palette.Surface.well.color)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("lfs.transfer.progress")
        } leading: {
            Text(statusText)
                .font(Metrics.Font.body)
                .foregroundStyle(state.failure == nil ? Palette.Text.secondary.color : Palette.Status.deleted.ink.color)
                .lineLimit(2)
                .accessibilityIdentifier("lfs.transfer.status")
        } buttons: {
            DialogConfirmButton(title: "Close", identifier: "lfs.transfer.close") { dismiss() }
                .disabled(state.isRunning)
        }
        .interactiveDismissDisabled(state.isRunning)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lfs.transferSheet")
        .task { await viewModel.transferLFS(transfer) }
    }

    private var statusText: String {
        if state.isRunning { return transfer == .fetch ? "Downloading…" : "Downloading and checking out…" }
        return state.failure ?? "Done"
    }
}
