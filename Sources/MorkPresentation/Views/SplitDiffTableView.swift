import AppKit
import SwiftUI

struct SplitDiffTableView: NSViewRepresentable {
    let document: DiffDocument
    let metrics: DiffMetrics

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let table = NSTableView()
        table.headerView = nil
        table.style = .plain
        table.intercellSpacing = .zero
        table.gridStyleMask = []
        table.selectionHighlightStyle = .none
        table.allowsEmptySelection = true
        table.usesAutomaticRowHeights = false
        table.backgroundColor = Palette.Surface.window.nsColor
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        let column = NSTableColumn(identifier: SplitDiffCellID.column)
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.dataSource = context.coordinator
        table.delegate = context.coordinator
        table.setAccessibilityIdentifier("filePreview.diff")
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.drawsBackground = true
        scroll.backgroundColor = Palette.Surface.window.nsColor
        context.coordinator.table = table
        scroll.contentView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.visibleWidthChanged), name: NSView.frameDidChangeNotification, object: scroll.contentView)
        context.coordinator.update(document: document, metrics: metrics)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.update(document: document, metrics: metrics)
    }

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        weak var table: NSTableView?
        private var document: DiffDocument?
        private var metrics = DiffMetrics.standard
        private var rows: [SplitDiffRow] = []
        private var attributed: [Int: NSAttributedString] = [:]
        private var font = NSFont.monospacedSystemFont(ofSize: DiffMetrics.standard.fontSize, weight: .regular)
        private var numberFont = NSFont.monospacedSystemFont(ofSize: DiffMetrics.standard.numberFontSize, weight: .regular)
        private var wrap: DiffWrapLayout?
        private var columnCounts: [Int: Int] = [:]

        private var wrapLayout: DiffWrapLayout? {
            let width = table?.enclosingScrollView?.contentView.bounds.width ?? 0
            let gutter = numberWidth > 0 ? numberWidth + Metrics.Diff.numberGap : 0
            return metrics.wrapLayout(textWidth: SplitDiffCell.sideWidth(of: width) - gutter - Metrics.Diff.textInset)
        }

        private var numberWidth: CGFloat {
            guard let document, document.lineNumberDigits > 0 else { return 0 }
            return CGFloat(document.lineNumberDigits) * metrics.numberCharacterWidth + Metrics.FilePreview.numberPadding
        }

        func update(document next: DiffDocument, metrics nextMetrics: DiffMetrics) {
            guard let table, document != next || metrics != nextMetrics else { return }
            document = next
            metrics = nextMetrics
            rows = SplitDiff.rows(from: next.lines)
            attributed = [:]
            columnCounts = [:]
            wrap = wrapLayout
            font = .monospacedSystemFont(ofSize: nextMetrics.fontSize, weight: .regular)
            numberFont = .monospacedSystemFont(ofSize: nextMetrics.numberFontSize, weight: .regular)
            table.rowHeight = nextMetrics.rowHeight
            table.tableColumns.first?.minWidth = (numberWidth + Metrics.FilePreview.sidePadding) * 2
            table.reloadData()
            table.sizeLastColumnToFit()
            table.scrollRowToVisible(0)
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            rows.count
        }

        func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
            false
        }

        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            guard rows.indices.contains(row) else { return metrics.rowHeight }
            switch rows[row].content {
            case .hunk:
                return Metrics.Diff.hunkRow
            case let .pair(left, right):
                guard let wrap else { return metrics.rowHeight }
                return wrap.height(forColumns: max(left.map(columns(of:)) ?? 0, right.map(columns(of:)) ?? 0))
            }
        }

        @objc func visibleWidthChanged() {
            guard let table, metrics.wrapsLines else { return }
            let next = wrapLayout
            guard next != wrap else { return }
            wrap = next
            guard !rows.isEmpty else { return }
            table.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: rows.indices))
            let visible = table.rows(in: table.visibleRect)
            guard visible.length > 0 else { return }
            table.reloadData(forRowIndexes: IndexSet(integersIn: visible.location..<(visible.location + visible.length)), columnIndexes: IndexSet(integer: 0))
        }

        private func columns(of line: DiffLine) -> Int {
            if let cached = columnCounts[line.id] { return cached }
            let count = DiffTabs.columns(of: line.text, width: metrics.tabWidth)
            columnCounts[line.id] = count
            return count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard rows.indices.contains(row) else { return nil }
            switch rows[row].content {
            case let .hunk(line):
                let cell = tableView.makeView(withIdentifier: SplitDiffCellID.hunk, owner: self) as? SplitHunkCell ?? SplitHunkCell()
                cell.identifier = SplitDiffCellID.hunk
                cell.configure(text: line.text)
                return cell
            case let .pair(left, right):
                let cell = tableView.makeView(withIdentifier: SplitDiffCellID.pair, owner: self) as? SplitDiffCell ?? SplitDiffCell()
                cell.identifier = SplitDiffCellID.pair
                cell.configure(
                    left: left.map { SplitDiffSide(line: $0, text: text(for: $0)) },
                    right: right.map { SplitDiffSide(line: $0, text: text(for: $0)) },
                    font: font,
                    numberFont: numberFont,
                    numberWidth: numberWidth,
                    wrap: wrap
                )
                return cell
            }
        }

        private func text(for line: DiffLine) -> NSAttributedString {
            if let cached = attributed[line.id] { return cached }
            let result = DiffLineText.make(line, font: font, tabWidth: metrics.tabWidth, showsInvisibles: metrics.showsInvisibles, wrapLineHeight: metrics.wrapsLines ? metrics.lineHeight : nil)
            attributed[line.id] = result
            return result
        }
    }
}

private enum SplitDiffCellID {
    static let column = NSUserInterfaceItemIdentifier("splitDiff.column")
    static let pair = NSUserInterfaceItemIdentifier("splitDiff.pair")
    static let hunk = NSUserInterfaceItemIdentifier("splitDiff.hunk")
}

struct SplitDiffSide {
    let line: DiffLine
    let text: NSAttributedString
}

final class SplitDiffCell: NSView {
    private let left = DiffLineCell()
    private let right = DiffLineCell()
    private var hasLeft = false
    private var hasRight = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        addSubview(left)
        addSubview(right)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool { true }

    static func sideWidth(of width: CGFloat) -> CGFloat {
        floor(width / 2)
    }

    func configure(left leftSide: SplitDiffSide?, right rightSide: SplitDiffSide?, font: NSFont, numberFont: NSFont, numberWidth: CGFloat, wrap: DiffWrapLayout? = nil) {
        hasLeft = leftSide != nil
        hasRight = rightSide != nil
        left.isHidden = leftSide == nil
        right.isHidden = rightSide == nil
        if let leftSide {
            var shown = leftSide.line
            shown.newNumber = leftSide.line.oldNumber
            left.configure(line: shown, text: leftSide.text, font: font, numberFont: numberFont, numberWidth: numberWidth, numberColumns: 1, source: nil, isSelected: false, allowsTextSelection: true, wrap: wrap)
        }
        if let rightSide {
            right.configure(line: rightSide.line, text: rightSide.text, font: font, numberFont: numberFont, numberWidth: numberWidth, numberColumns: 1, source: nil, isSelected: false, allowsTextSelection: true, wrap: wrap)
        }
        needsLayout = true
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        let half = Self.sideWidth(of: bounds.width)
        left.frame = NSRect(x: 0, y: 0, width: half, height: bounds.height)
        right.frame = NSRect(x: half + 1, y: 0, width: max(0, bounds.width - half - 1), height: bounds.height)
    }

    override func draw(_ dirtyRect: NSRect) {
        let half = floor(bounds.width / 2)
        if !hasLeft { drawHatch(in: NSRect(x: 0, y: 0, width: half, height: bounds.height)) }
        if !hasRight { drawHatch(in: NSRect(x: half + 1, y: 0, width: max(0, bounds.width - half - 1), height: bounds.height)) }
        Palette.Surface.border.nsColor.setFill()
        NSRect(x: half, y: 0, width: 1, height: bounds.height).fill()
    }

    private func drawHatch(in rect: NSRect) {
        Palette.Diff.gutter.nsColor.setFill()
        rect.fill()
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: rect).addClip()
        let path = NSBezierPath()
        let spacing = Metrics.FilePreview.hatchSpacing
        var x = rect.minX - rect.height
        while x < rect.maxX {
            path.move(to: NSPoint(x: x, y: rect.maxY))
            path.line(to: NSPoint(x: x + rect.height, y: rect.minY))
            x += spacing
        }
        Palette.Surface.border.nsColor.setStroke()
        path.lineWidth = 1
        path.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }
}

final class SplitHunkCell: NSView {
    private let label = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        label.lineBreakMode = .byTruncatingTail
        label.font = .monospacedSystemFont(ofSize: Metrics.FontSize.caption, weight: .regular)
        label.textColor = Palette.Text.secondary.nsColor
        addSubview(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(text: String) {
        label.stringValue = text
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let height = label.intrinsicContentSize.height
        let inset = Metrics.Spacing.m
        label.frame = NSRect(x: inset, y: (bounds.height - height) / 2, width: max(0, bounds.width - inset * 2), height: height)
    }

    override func draw(_ dirtyRect: NSRect) {
        Palette.Diff.hunk.nsColor.setFill()
        bounds.fill()
    }
}
