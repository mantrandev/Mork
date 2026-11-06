import AppKit
import MorkDomain
import SwiftUI

struct ComparedFileTable: NSViewRepresentable {
    let files: [ComparedFile]
    let revision: Int
    let selectedID: String?
    let onSelect: (String?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let table = NSTableView()
        table.headerView = nil
        table.style = .inset
        table.intercellSpacing = .zero
        table.usesAutomaticRowHeights = false
        table.rowHeight = Metrics.Row.list
        table.allowsEmptySelection = true
        table.allowsMultipleSelection = false
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        let column = NSTableColumn(identifier: ComparedFileCell.identifier)
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.dataSource = context.coordinator
        table.delegate = context.coordinator
        table.setAccessibilityIdentifier("compareLocal.list")
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        context.coordinator.table = table
        context.coordinator.update(self)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.update(self)
    }

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        weak var table: NSTableView?
        private var view: ComparedFileTable?
        private var rows: [String: Int] = [:]
        private var isApplyingSelection = false

        func update(_ next: ComparedFileTable) {
            let previous = view
            view = next
            guard let table else { return }
            if previous?.revision != next.revision {
                rows = Dictionary(next.files.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
                isApplyingSelection = true
                table.reloadData()
                table.sizeLastColumnToFit()
                isApplyingSelection = false
            } else if previous?.selectedID == next.selectedID {
                return
            }
            applySelection(next.selectedID)
        }

        private func applySelection(_ id: String?) {
            guard let table else { return }
            let row = id.flatMap { rows[$0] }
            guard table.selectedRow != (row ?? -1) else { return }
            isApplyingSelection = true
            if let row {
                table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                table.scrollRowToVisible(row)
            } else {
                table.deselectAll(nil)
            }
            isApplyingSelection = false
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            view?.files.count ?? 0
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let files = view?.files, files.indices.contains(row) else { return nil }
            let cell = tableView.makeView(withIdentifier: ComparedFileCell.identifier, owner: nil) as? ComparedFileCell ?? ComparedFileCell()
            cell.configure(files[row])
            return cell
        }

        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            AccentSelectionRowView.make(in: tableView)
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !isApplyingSelection, let table, let files = view?.files else { return }
            let row = table.selectedRow
            view?.onSelect(files.indices.contains(row) ? files[row].id : nil)
        }
    }
}

final class ComparedFileCell: NSView {
    static let identifier = NSUserInterfaceItemIdentifier("compareLocal.cell")

    private let badge = StatusBadgeView()
    private let icon = NSImageView()
    private let path = NSTextField(labelWithString: "")
    private let note = NSTextField(labelWithString: "untracked")
    private var file: ComparedFile?

    init() {
        super.init(frame: .zero)
        identifier = Self.identifier
        icon.setAccessibilityElement(false)
        path.lineBreakMode = .byTruncatingHead
        path.cell?.truncatesLastVisibleLine = true
        path.setAccessibilityElement(false)
        note.font = .systemFont(ofSize: Metrics.FontSize.caption)
        note.textColor = Palette.Text.secondary.nsColor
        note.setAccessibilityElement(false)
        [badge, icon, path, note].forEach(addSubview)
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(_ file: ComparedFile) {
        guard file != self.file else { return }
        self.file = file
        let text = FilePathParts.displayText(path: file.path, originalPath: file.originalPath)
        badge.letter = file.status
        icon.image = FileIconCache.icon(forExtension: FilePathParts(file.path).fileExtension)
        path.attributedStringValue = PathLabel.attributed(text, style: .split, font: .systemFont(ofSize: Metrics.CommitDetails.fileFont), isDeleted: file.status == "D")
        note.isHidden = !file.isUntracked
        toolTip = text
        setAccessibilityIdentifier("compareLocal.\(file.isUntracked ? "untracked" : "file").\(file.path)")
        setAccessibilityLabel(text)
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let height = bounds.height
        let column = Metrics.Icon.column
        var x = Metrics.Spacing.xs
        func centered(_ viewHeight: CGFloat) -> CGFloat { ((height - viewHeight) / 2).rounded() }
        badge.frame = NSRect(x: x, y: centered(column), width: column, height: column)
        x += column + Metrics.ChangeRow.gap
        icon.frame = NSRect(x: x, y: centered(column), width: column, height: column)
        x += column + Metrics.ChangeRow.gap
        var right = bounds.width - Metrics.Spacing.xs
        if !note.isHidden {
            let size = note.intrinsicContentSize
            right -= ceil(size.width)
            note.frame = NSRect(x: right, y: centered(size.height), width: ceil(size.width), height: size.height)
            right -= Metrics.Spacing.s
        }
        let pathHeight = path.intrinsicContentSize.height
        path.frame = NSRect(x: x, y: centered(pathHeight), width: max(right - x, 0), height: pathHeight)
    }
}
