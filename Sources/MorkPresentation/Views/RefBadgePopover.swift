import MorkDomain
import Observation
import SwiftUI

enum RefBadgePopover {
    static let openDelay: Duration = .milliseconds(500)
    static let closeDelay: Duration = .milliseconds(300)

    nonisolated static func names(of label: RefLabel) -> [String] {
        switch label.kind {
        case .more: label.others
        case .tag where !label.others.isEmpty: [label.name] + label.others
        default: []
        }
    }
}

struct RefBadgePopoverState: Equatable {
    private(set) var isPresented = false
    private(set) var isPinned = false
    private var isOverBadge = false
    private var isOverPopover = false

    var shouldOpen: Bool { isOverBadge && !isPresented }
    var shouldClose: Bool { !isPinned && !isOverBadge && !isOverPopover }

    mutating func hoverBadge(_ inside: Bool) { isOverBadge = inside }
    mutating func hoverPopover(_ inside: Bool) { isOverPopover = inside }
    mutating func open() { isPresented = true }
    mutating func close() { isPresented = false }

    mutating func click() {
        isPinned = true
        isPresented = true
    }

    mutating func dismiss() {
        isPresented = false
        isPinned = false
        isOverPopover = false
    }
}

@MainActor
@Observable
final class HistoryRefMenus {
    let viewModel: RepositoryViewModel
    var sheet: WorkspaceSheet?
    var confirmation: WorkspaceConfirmation?

    init(viewModel: RepositoryViewModel) {
        self.viewModel = viewModel
    }
}

struct RefBadgeButton: View {
    let label: RefLabel
    let lane: Int
    let menus: HistoryRefMenus
    @State private var state = RefBadgePopoverState()
    @State private var timer: Task<Void, Never>?

    var body: some View {
        RefBadge(label: label, lane: lane)
            .fixedSize()
            .contentShape(Rectangle())
            .onHover { inside in
                state.hoverBadge(inside)
                schedule(entering: inside)
            }
            .onTapGesture {
                timer?.cancel()
                state.click()
            }
            .popover(isPresented: Binding(get: { state.isPresented }, set: { if !$0 { state.dismiss() } }), arrowEdge: .bottom) {
                RefBadgeList(names: RefBadgePopover.names(of: label), menus: menus)
                    .onHover { inside in
                        state.hoverPopover(inside)
                        schedule(entering: inside)
                    }
            }
            .onChange(of: menus.sheet != nil) { _, presenting in
                if presenting { state.dismiss() }
            }
            .accessibilityAddTraits(.isButton)
    }

    private func schedule(entering: Bool) {
        timer?.cancel()
        timer = Task { @MainActor in
            try? await Task.sleep(for: entering ? RefBadgePopover.openDelay : RefBadgePopover.closeDelay)
            guard !Task.isCancelled else { return }
            if state.shouldOpen {
                state.open()
            } else if state.isPresented, state.shouldClose {
                state.close()
            }
        }
    }
}

private struct RefBadgeList: View {
    let names: [String]
    let menus: HistoryRefMenus

    var body: some View {
        List(names, id: \.self) { name in
            Text(name)
                .font(Metrics.Font.body)
                .lineLimit(1)
                .truncationMode(.middle)
                .listRowInsets(Metrics.listRowInsets)
                .contextMenu { menu(for: name) }
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, Metrics.Row.list)
        .frame(width: Metrics.RefPopover.width, height: min(CGFloat(names.count) * Metrics.Row.list + Metrics.Spacing.s * 2, Metrics.RefPopover.maxHeight))
        .accessibilityIdentifier("history.refPopover")
    }

    @ViewBuilder
    private func menu(for name: String) -> some View {
        if let tag = menus.viewModel.tags.first(where: { $0.name == name }) {
            TagMenu(tag: tag, viewModel: menus.viewModel, sheet: Binding(get: { menus.sheet }, set: { menus.sheet = $0 }))
        } else {
            Button("Copy Name") { Pasteboard.copy(name) }
        }
    }
}
