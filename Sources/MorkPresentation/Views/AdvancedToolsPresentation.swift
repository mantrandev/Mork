import MorkDomain
import SwiftUI

extension View {
    func advancedToolsPresentation(_ viewModel: RepositoryViewModel) -> some View {
        modifier(AdvancedToolsPresentation(viewModel: viewModel, tools: viewModel.advanced))
    }
}

private struct AdvancedToolsPresentation: ViewModifier {
    let viewModel: RepositoryViewModel
    @Bindable var tools: AdvancedTools

    func body(content: Content) -> some View {
        content
            .task(id: viewModel.hasLoaded) { if viewModel.hasLoaded { await viewModel.detectLFSIfNeeded() } }
            .sheet(item: $tools.lfsSheet) { sheet in
                switch sheet {
                case .track:
                    TextInputSheet(title: "Track with Git LFS", placeholder: "*.psd", secondaryPlaceholder: nil, confirmTitle: "Track", identifier: "lfs.trackSheet", message: "Adds the pattern to .gitattributes. Files that match it are stored in Git LFS from their next git add.", glyph: "externaldrive.badge.plus", command: DialogCommands.lfsTrack) { pattern, _ in
                        Task { await viewModel.trackLFS(pattern: pattern) }
                    }
                case .untrack:
                    LFSUntrackSheet(viewModel: viewModel)
                case let .transfer(transfer):
                    LFSTransferSheet(viewModel: viewModel, transfer: transfer)
                }
            }
            .sheet(item: $tools.gitFlow) { GitFlowSheet(session: $0) }
            .sheet(item: $tools.treemap) { TreemapSheet(session: $0, repository: viewModel) }
            .sheet(item: $tools.benchmark) { BenchmarkSheet(session: $0) }
    }
}
