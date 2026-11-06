import AppKit
import MorkDomain
import SwiftUI

struct BranchPickerTable: NSViewRepresentable {
    let picker: BranchPickerViewModel
    let revision: Int
    let selectedIndex: Int
    let onHover: (BranchPickerItem) -> Void
    let onActivate: (BranchPickerItem) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> BranchPickerScrollView {
        let table = BranchPickerTableView()
        table.headerView = nil
        table.style = .plain
        table.intercellSpacing = .zero
        table.gridStyleMask = []
        table.selectionHighlightStyle = .none
        table.allowsEmptySelection = true
        table.usesAutomaticRowHeights = false
        table.backgroundColor = .clear
        table.rowHeight = Metrics.Dropdown.row
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        let column = NSTableColumn(identifier: BranchPickerCell.identifier)
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.dataSource = context.coordinator
        table.delegate = context.coordinator
        table.target = context.coordinator
        table.action = #selector(Coordinator.click)
        table.onHover = { [weak coordinator = context.coordinator] row in coordinator?.hover(row) }
        table.setAccessibilityIdentifier("branchPicker.list")
        let scroll = BranchPickerScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.contentInsets = NSEdgeInsets(top: Metrics.Spacing.xs, left: 0, bottom: Metrics.Spacing.xs, right: 0)
        scroll.automaticallyAdjustsContentInsets = false
        context.coordinator.table = table
        context.coordinator.update(self)
        scroll.pendingRow = context.coordinator.tableRow(forItem: selectedIndex)
        return scroll
    }

    func updateNSView(_ scroll: BranchPickerScrollView, context: Context) {
        context.coordinator.update(self)
    }

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        weak var table: NSTableView?
        private var view: BranchPickerTable?
        private var branchCount = 0
        private var worktreeCount = 0

        func update(_ next: BranchPickerTable) {
            let previous = view
            view = next
            guard let table else { return }
            if previous?.revision != next.revision {
                branchCount = next.picker.branches.count
                worktreeCount = next.picker.worktrees.count
                table.reloadData()
                table.sizeLastColumnToFit()
                if previous != nil { table.scrollRowToVisible(0) }
                return
            }
            guard let previous, previous.selectedIndex != next.selectedIndex else { return }
            let rows = [previous.selectedIndex, next.selectedIndex].compactMap(tableRow(forItem:))
            for row in rows { (table.rowView(atRow: row, makeIfNecessary: false) as? BranchPickerRowView)?.isChosen = row == tableRow(forItem: next.selectedIndex) }
            table.reloadData(forRowIndexes: IndexSet(rows), columnIndexes: IndexSet(integer: 0))
            if let row = tableRow(forItem: next.selectedIndex) { table.scrollRowToVisible(row) }
        }

        private var hasHeader: Bool { worktreeCount > 0 }

        func tableRow(forItem index: Int) -> Int? {
            guard index >= 0, index < branchCount + worktreeCount else { return nil }
            return index < branchCount ? index : index + 1
        }

        private func itemIndex(forRow row: Int) -> Int? {
            if row < branchCount { return row }
            if hasHeader, row == branchCount { return nil }
            let index = row - 1
            return index < branchCount + worktreeCount ? index : nil
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            branchCount + worktreeCount + (hasHeader ? 1 : 0)
        }

        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            hasHeader && row == branchCount ? Metrics.Dropdown.header : Metrics.Dropdown.row
        }

        func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
            false
        }

        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            let rowView = BranchPickerRowView()
            rowView.isChosen = itemIndex(forRow: row).map { $0 == view?.selectedIndex } ?? false
            return rowView
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let view else { return nil }
            guard let index = itemIndex(forRow: row), let item = view.picker.item(at: index) else {
                let header = tableView.makeView(withIdentifier: BranchPickerHeaderCell.identifier, owner: nil) as? BranchPickerHeaderCell ?? BranchPickerHeaderCell()
                return header
            }
            let cell = tableView.makeView(withIdentifier: BranchPickerCell.identifier, owner: nil) as? BranchPickerCell ?? BranchPickerCell()
            cell.configure(item, isSelected: index == view.selectedIndex) { [weak self] in self?.view?.onActivate(item) }
            return cell
        }

        @objc func click() {
            guard let table, table.clickedRow >= 0, let index = itemIndex(forRow: table.clickedRow), let item = view?.picker.item(at: index) else { return }
            view?.onActivate(item)
        }

        func hover(_ row: Int) {
            guard let index = itemIndex(forRow: row), index != view?.selectedIndex, let item = view?.picker.item(at: index), item.isEnabled else { return }
            view?.onHover(item)
        }
    }
}

final class BranchPickerScrollView: NSScrollView {
    var pendingRow: Int?

    override func layout() {
        super.layout()
        guard let row = pendingRow, let table = documentView as? NSTableView, contentView.bounds.height > 0, table.numberOfRows > row else { return }
        pendingRow = nil
        let rect = table.rect(ofRow: row)
        let maxY = max(table.frame.height - contentView.bounds.height, 0)
        let centered = ((rect.midY - contentView.bounds.height / 2) / Metrics.Dropdown.row).rounded() * Metrics.Dropdown.row
        let y = min(max(centered, 0), maxY) - contentInsets.top
        contentView.scroll(to: NSPoint(x: 0, y: y))
        reflectScrolledClipView(contentView)
    }
}

final class BranchPickerTableView: NSTableView {
    var onHover: ((Int) -> Void)?
    private var tracking: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseMoved(with event: NSEvent) {
        let row = row(at: convert(event.locationInWindow, from: nil))
        if row >= 0 { onHover?(row) }
    }
}

final class BranchPickerRowView: NSTableRowView {
    var isChosen = false {
        didSet { if isChosen != oldValue { needsDisplay = true } }
    }

    override func drawBackground(in dirtyRect: NSRect) {
        guard isChosen else { return }
        Palette.Text.primary.nsColor.withAlphaComponent(Palette.Ink.selection).setFill()
        let rect = bounds.insetBy(dx: Metrics.Spacing.xs, dy: 0)
        NSBezierPath(roundedRect: rect, xRadius: Metrics.Radius.control, yRadius: Metrics.Radius.control).fill()
    }

    override func drawSelection(in dirtyRect: NSRect) {}
}

final class BranchPickerHeaderCell: NSView {
    static let identifier = NSUserInterfaceItemIdentifier("branchPicker.header")
    private let label = NSTextField(labelWithString: "Worktrees")

    init() {
        super.init(frame: .zero)
        identifier = Self.identifier
        label.font = .systemFont(ofSize: Metrics.FontSize.caption, weight: .semibold)
        label.textColor = Palette.Text.secondary.nsColor
        addSubview(label)
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel("Worktrees")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layout() {
        super.layout()
        let size = label.intrinsicContentSize
        label.frame = NSRect(x: BranchPickerCell.inset + Metrics.Spacing.xs, y: Metrics.Spacing.xs, width: bounds.width - BranchPickerCell.inset * 2, height: size.height)
    }
}

final class BranchPickerCell: NSView {
    static let identifier = NSUserInterfaceItemIdentifier("branchPicker.cell")
    static let inset = Metrics.Spacing.xs + Metrics.Spacing.s

    private let check = NSImageView()
    private let icon = NSImageView()
    private let title = NSTextField(labelWithString: "")
    private let trailing = NSTextField(labelWithString: "")
    private let warning = NSImageView()
    private var press: (() -> Void)?

    private static let checkImage = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: Metrics.FontSize.caption, weight: .bold))
    private static let branchImage = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: Metrics.Icon.regular, weight: .regular))
    private static let worktreeImage = NSImage(systemSymbolName: "square.on.square.dashed", accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: Metrics.Icon.regular, weight: .regular))
    private static let warningImage = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Upstream is gone")?
        .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: Metrics.Icon.warningBadge, weight: .bold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [Palette.Status.onFill.nsColor, Palette.Status.conflict.ink.nsColor])))

    init() {
        super.init(frame: .zero)
        identifier = Self.identifier
        check.image = Self.checkImage
        warning.image = Self.warningImage
        title.lineBreakMode = .byTruncatingMiddle
        title.cell?.truncatesLastVisibleLine = true
        trailing.font = .monospacedDigitSystemFont(ofSize: Metrics.FontSize.caption, weight: .regular)
        trailing.alignment = .right
        [check, icon, title, trailing, warning].forEach(addSubview)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(_ item: BranchPickerItem, isSelected: Bool, press: @escaping () -> Void) {
        self.press = press
        let primary = Palette.Text.primary.nsColor
        let secondary = Palette.Text.secondary.nsColor
        let isChecked: Bool
        let text: String
        let dimmed: Range<Int>
        switch item.kind {
        case let .branch(branch):
            isChecked = branch.isCurrent
            text = branch.name
            dimmed = 0..<(branch.name.lastIndex(of: "/").map { branch.name[...$0].unicodeScalars.count } ?? 0)
            icon.image = Self.branchImage
            trailing.stringValue = branch.trackSummary ?? ""
            warning.isHidden = !branch.isUpstreamGone
            toolTip = branch.upstream.map { branch.isUpstreamGone ? "Upstream \($0) is gone" : "upstream: \($0)" }
            setAccessibilityIdentifier("branchPicker.\(branch.name)")
            setAccessibilityLabel(branch.name)
        case let .worktree(row):
            isChecked = row.isCurrent
            text = BranchPickerViewModel.title(of: row.worktree)
            dimmed = row.worktree.name.unicodeScalars.count..<text.unicodeScalars.count
            icon.image = Self.worktreeImage
            trailing.stringValue = ""
            warning.isHidden = true
            toolTip = row.worktree.path
            setAccessibilityIdentifier("branchPicker.worktree.\(row.worktree.name)")
            setAccessibilityLabel(text)
        }
        check.isHidden = !isChecked
        check.contentTintColor = Palette.Accent.text.nsColor
        icon.contentTintColor = secondary
        trailing.textColor = secondary
        title.attributedStringValue = Self.title(text, dimmed: dimmed, highlights: item.highlights, isChecked: isChecked, primary: primary, secondary: secondary)
        alphaValue = item.isEnabled ? 1 : Metrics.Opacity.dimmed
        setAccessibilityValue(isChecked ? "current" : isSelected ? "selected" : "")
        setAccessibilityEnabled(item.isEnabled)
        needsLayout = true
    }

    static func title(_ text: String, dimmed: Range<Int>, highlights: [Range<Int>], isChecked: Bool, primary: NSColor, secondary: NSColor) -> NSAttributedString {
        let size = Metrics.FontSize.title
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingMiddle
        let result = NSMutableAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: isChecked ? .semibold : .regular),
            .foregroundColor: primary,
            .paragraphStyle: paragraph
        ])
        let utf16 = text.utf16
        let scalars = text.unicodeScalars
        func range(_ span: Range<Int>) -> NSRange? {
            guard span.lowerBound >= 0, span.upperBound <= scalars.count, !span.isEmpty else { return nil }
            let start = scalars.index(scalars.startIndex, offsetBy: span.lowerBound)
            let end = scalars.index(start, offsetBy: span.count)
            return NSRange(location: utf16.distance(from: utf16.startIndex, to: start), length: utf16.distance(from: start, to: end))
        }
        if let span = range(dimmed) {
            result.addAttribute(.foregroundColor, value: secondary, range: span)
        }
        for highlight in highlights {
            guard let span = range(highlight) else { continue }
            result.addAttributes([.font: NSFont.systemFont(ofSize: size, weight: .bold), .underlineStyle: NSUnderlineStyle.single.rawValue], range: span)
        }
        return result
    }

    override func layout() {
        super.layout()
        let height = bounds.height
        var x = Self.inset
        func place(_ view: NSView, width: CGFloat, height viewHeight: CGFloat) {
            view.frame = NSRect(x: x, y: ((height - viewHeight) / 2).rounded(), width: width, height: viewHeight)
        }
        place(check, width: Metrics.Dropdown.checkColumn, height: Metrics.Dropdown.checkColumn)
        x += Metrics.Dropdown.checkColumn + Metrics.Spacing.s
        place(icon, width: Metrics.Icon.column, height: Metrics.Icon.column)
        let badge = Metrics.Icon.small
        warning.frame = NSRect(x: icon.frame.maxX - badge + Metrics.Spacing.xs, y: icon.frame.minY - Metrics.Spacing.xxs, width: badge, height: badge)
        x += Metrics.Icon.column + Metrics.Spacing.s
        var right = bounds.width - Self.inset
        let trailingWidth = trailing.stringValue.isEmpty ? 0 : ceil(trailing.intrinsicContentSize.width)
        trailing.frame = NSRect(x: right - trailingWidth, y: ((height - trailing.intrinsicContentSize.height) / 2).rounded(), width: trailingWidth, height: trailing.intrinsicContentSize.height)
        if trailingWidth > 0 { right -= trailingWidth + Metrics.Spacing.s }
        let titleHeight = title.intrinsicContentSize.height
        title.frame = NSRect(x: x, y: ((height - titleHeight) / 2).rounded(), width: max(right - x, 0), height: titleHeight)
    }

    override func accessibilityPerformPress() -> Bool {
        press?()
        return true
    }
}
