import MorkDomain
import SwiftUI

extension View {
    func branchDragAndDrop(_ branch: Branch, viewModel: RepositoryViewModel) -> some View {
        modifier(BranchDragAndDrop(branch: branch, viewModel: viewModel))
    }

    func branchDropDialog(_ viewModel: RepositoryViewModel) -> some View {
        modifier(BranchDropDialog(viewModel: viewModel))
    }
}

private struct BranchDragAndDrop: ViewModifier {
    let branch: Branch
    let viewModel: RepositoryViewModel
    @State private var isTargeted = false

    func body(content: Content) -> some View {
        content
            .draggable(branch.name) {
                Label(branch.name, systemImage: "arrow.triangle.branch")
                    .padding(Metrics.Spacing.xs)
            }
            .dropDestination(for: String.self) { names, _ in
                guard let name = names.first else { return false }
                return viewModel.dropBranch(named: name, onto: branch.name)
            } isTargeted: { isTargeted = $0 }
            .overlay {
                if isTargeted {
                    RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous)
                        .strokeBorder(Palette.Accent.fill.color, lineWidth: Metrics.Sidebar.dropTargetBorder)
                        .accessibilityHidden(true)
                }
            }
    }
}

private struct BranchDropDialog: ViewModifier {
    let viewModel: RepositoryViewModel

    func body(content: Content) -> some View {
        content.morkConfirmation(item: Binding(get: { viewModel.pendingBranchDrop }, set: { viewModel.pendingBranchDrop = $0 })) { request in
            MorkConfirmation(
                kind: .options,
                glyph: "arrow.triangle.merge",
                title: request.title,
                message: request.dialogMessage,
                actions: request.available.map { option in
                    DialogAction(title: option.title, command: option.commands.joined(separator: " && "), identifier: option.action == .merge ? "branchDrop.merge" : "branchDrop.rebase") {
                        Task { await viewModel.performBranchDrop(option) }
                    }
                },
                cancelIdentifier: "branchDrop.cancel"
            )
        }
    }
}

extension BranchDropRequest {
    var dialogMessage: String {
        let blocked = options.compactMap { option in option.blockedReason.map { "\(option.title): \($0)" } }
        let intro = "Merge brings the commits of \(source.name) into \(target.name). Rebase replays the commits of \(source.name) on top of \(target.name)."
        return ([intro] + blocked).joined(separator: "\n")
    }
}
