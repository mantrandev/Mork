import MorkDomain
import SwiftUI

struct BranchPickerPanel: View {
    @Bindable var picker: BranchPickerViewModel
    let maximumHeight: CGFloat
    let onCheckout: (Branch) -> Void
    let onOpenWorktree: (Worktree) -> Void
    let onNewBranch: () -> Void
    let onFetch: () -> Void
    let onClose: () -> Void
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            field
            Hairline()
            if picker.count == 0 {
                Text(picker.query.isEmpty ? "No local branches" : "No matching branches")
                    .font(Metrics.Font.body)
                    .foregroundStyle(Palette.Text.secondary.color)
                    .frame(maxWidth: .infinity)
                    .frame(height: Metrics.Dropdown.row * 2)
                    .accessibilityIdentifier("branchPicker.empty")
            } else {
                list
            }
            Hairline()
            footer
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("branchPicker.panel")
        .task {
            for _ in 0..<20 where !isFieldFocused {
                isFieldFocused = true
                try? await Task.sleep(for: .milliseconds(25))
            }
        }
    }

    private var field: some View {
        HStack(spacing: Metrics.Spacing.s) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: Metrics.Icon.regular))
                .foregroundStyle(Palette.Text.tertiary.color)
                .frame(width: Metrics.Dropdown.checkColumn)
            TextField("Filter branches", text: $picker.query)
                .textFieldStyle(.plain)
                .font(Metrics.Font.title)
                .foregroundStyle(Palette.Text.primary.color)
                .focused($isFieldFocused)
                .onSubmit(activateSelection)
                .onKeyPress(.upArrow) {
                    picker.moveSelection(by: -1)
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    picker.moveSelection(by: 1)
                    return .handled
                }
                .onKeyPress(.escape) {
                    onClose()
                    return .handled
                }
                .onExitCommand(perform: onClose)
                .accessibilityIdentifier("branchPicker.search")
        }
        .padding(.horizontal, Metrics.Spacing.m)
        .frame(height: Metrics.Dropdown.searchRow)
    }

    private var list: some View {
        BranchPickerTable(
            picker: picker,
            revision: picker.revision,
            selectedIndex: picker.selectedIndex,
            onHover: { picker.select($0) },
            onActivate: activate
        )
        .frame(height: listHeight)
    }

    private var footer: some View {
        HStack(spacing: Metrics.Spacing.xs) {
            FooterButton(title: "New Branch…", systemImage: "plus", shortcut: "⇧⌘B", identifier: "branchPicker.newBranch") {
                onClose()
                onNewBranch()
            }
            Spacer(minLength: Metrics.Spacing.s)
            FooterButton(title: "Fetch", systemImage: "arrow.triangle.2.circlepath", shortcut: "⇧⌘F", identifier: "branchPicker.fetch") {
                onClose()
                onFetch()
            }
        }
        .padding(.horizontal, Metrics.Spacing.xs)
        .frame(height: Metrics.Dropdown.footer)
    }

    private var listHeight: CGFloat {
        let headers = picker.worktrees.isEmpty ? 0 : Metrics.Dropdown.header
        let rows = CGFloat(picker.count) * Metrics.Dropdown.row + headers + Metrics.Spacing.s
        let chrome = Metrics.Dropdown.searchRow + Metrics.Dropdown.footer + Metrics.Line.hairline * 2
        return min(rows, max(maximumHeight - chrome, Metrics.Dropdown.row * 4))
    }

    private func activateSelection() {
        if let item = picker.selectedItem { activate(item) }
    }

    private func activate(_ item: BranchPickerItem) {
        guard item.isEnabled else { return }
        onClose()
        switch item.kind {
        case let .branch(branch):
            if !branch.isCurrent { onCheckout(branch) }
        case let .worktree(row):
            if !row.isCurrent { onOpenWorktree(row.worktree) }
        }
    }
}

private struct FooterButton: View {
    let title: String
    let systemImage: String
    let shortcut: String
    let identifier: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Metrics.Spacing.xs + Metrics.Spacing.xxs) {
                Image(systemName: systemImage)
                    .font(Metrics.Font.caption.weight(.semibold))
                    .foregroundStyle(Palette.Text.secondary.color)
                Text(title)
                    .font(Metrics.Font.body)
                    .foregroundStyle(Palette.Text.primary.color)
                Text(shortcut)
                    .font(Metrics.Font.caption)
                    .foregroundStyle(Palette.Text.secondary.color)
            }
            .padding(.horizontal, Metrics.Spacing.s)
            .frame(height: Metrics.Control.regular)
            .background(SelectionHighlight(isSelected: false, isHovered: isHovered))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityIdentifier(identifier)
    }
}
