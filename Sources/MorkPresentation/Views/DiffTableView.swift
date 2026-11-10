import AppKit
import MorkDomain
import SwiftUI

struct DiffTableView: NSViewRepresentable {
    let document: DiffDocument
    let metrics: DiffMetrics
    let hunks: [DiffHunk]
    let actions: [HunkAction]
    let perform: (HunkAction, DiffHunk) -> Void
    let lineModel: RepositoryViewModel?
    let performLines: (HunkAction) -> Void
    let lineState: DiffLineState
    let showsRawDiff: Bool
    let toggleRawDiff: (() -> Void)?
    var menuModel: RepositoryViewModel?
    var hidesFileCards = false
    var hunkJump: DiffHunkJump?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let table = DiffNSTableView()
        table.headerView = nil
        table.style = .plain
        table.intercellSpacing = .zero
        table.gridStyleMask = []
        table.selectionHighlightStyle = .none
        table.allowsEmptySelection = true
        table.usesAutomaticRowHeights = false
        table.floatsGroupRows = false
        table.backgroundColor = Palette.Surface.window.nsColor
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        let column = NSTableColumn(identifier: DiffCellID.column)
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.dataSource = context.coordinator
        table.delegate = context.coordinator
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = true
        scroll.backgroundColor = Palette.Surface.window.nsColor
        context.coordinator.table = table
        table.onHover = { [weak coordinator = context.coordinator] point in coordinator?.hover(at: point) }
        scroll.contentView.postsFrameChangedNotifications = true
        scroll.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.visibleWidthChanged), name: NSView.frameDidChangeNotification, object: scroll.contentView)
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.visibleBoundsChanged), name: NSView.boundsDidChangeNotification, object: scroll.contentView)
        context.coordinator.update(self)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.update(self)
    }

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        weak var table: NSTableView?
        private var view: DiffTableView?
        private var attributed: [Int: NSAttributedString] = [:]
        private var cardHeights: [Int: CGFloat] = [:]
        private var measuredWidth: CGFloat = 0
        private var cardSizer: NSHostingController<DiffFileRowContent>?
        private var font = NSFont.monospacedSystemFont(ofSize: DiffMetrics.standard.fontSize, weight: .regular)
        private var numberFont = NSFont.monospacedSystemFont(ofSize: DiffMetrics.standard.numberFontSize, weight: .regular)
        private var rows: [Int] = []
        private var hunkRows: [Int] = []
        private var hunkMap = DiffHunkRows()
        private var hoveredHunk: Int?
        private let outline = DiffHoverOutline()
        private var actionsHost: NSHostingView<HunkHoverActions>?
        private var numberColumns = 2
        private var handledJump: Int?
        private var wrap: DiffWrapLayout?
        private var columnCounts: [Int: Int] = [:]

        var numberWidth: CGFloat {
            guard let view, view.document.lineNumberDigits > 0 else { return 0 }
            return CGFloat(view.document.lineNumberDigits) * view.metrics.numberCharacterWidth + Metrics.Diff.numberPadding
        }

        private var gutterWidth: CGFloat {
            numberWidth > 0 ? (numberWidth + Metrics.Diff.numberGap) * CGFloat(numberColumns) : 0
        }

        private var wrapLayout: DiffWrapLayout? {
            let width = table?.enclosingScrollView?.contentView.bounds.width ?? 0
            return view?.metrics.wrapLayout(textWidth: width - gutterWidth - Metrics.Diff.textInset)
        }

        func update(_ next: DiffTableView) {
            let previous = view
            view = next
            guard let table else { return }
            let documentChanged = previous?.document != next.document || previous?.metrics != next.metrics || previous?.hidesFileCards != next.hidesFileCards
            if documentChanged {
                attributed = [:]
                cardHeights = [:]
                columnCounts = [:]
                indexRows(next)
                font = .monospacedSystemFont(ofSize: next.metrics.fontSize, weight: .regular)
                numberFont = .monospacedSystemFont(ofSize: next.metrics.numberFontSize, weight: .regular)
                table.rowHeight = next.metrics.rowHeight
                wrap = wrapLayout
                table.enclosingScrollView?.hasHorizontalScroller = !next.metrics.wrapsLines
                table.tableColumns.first?.minWidth = next.metrics.wrapsLines
                    ? gutterWidth + Metrics.Diff.textInset + Metrics.Diff.wrapMinimumColumns * next.metrics.characterWidth
                    : CGFloat(next.document.maxColumns) * next.metrics.characterWidth + numberWidth * 2 + Metrics.Diff.columnSlack
                table.reloadData()
                table.sizeLastColumnToFit()
                handledJump = next.hunkJump?.id
                hoveredHunk = nil
                refreshHover()
                return
            }
            if let jump = next.hunkJump, jump.id != handledJump {
                handledJump = jump.id
                scroll(jump.direction)
            }
            if previous?.showsRawDiff != next.showsRawDiff {
                remeasureCards()
            }
            if previous?.lineState != next.lineState || previous?.actions != next.actions {
                layoutHover()
            }
            if previous?.showsRawDiff != next.showsRawDiff || previous?.actions != next.actions {
                let visible = table.rows(in: table.visibleRect)
                guard visible.length > 0 else { return }
                table.reloadData(forRowIndexes: IndexSet(integersIn: visible.location..<(visible.location + visible.length)), columnIndexes: IndexSet(integer: 0))
            } else if previous?.lineState.selection != next.lineState.selection {
                showSelection(next.lineState.selection)
            }
        }

        private func showSelection(_ selection: DiffLineSelection) {
            guard let table else { return }
            let visible = table.rows(in: table.visibleRect)
            for row in visible.location..<(visible.location + visible.length) {
                (table.view(atColumn: 0, row: row, makeIfNecessary: false) as? DiffLineCell)?.showSelection(selection)
            }
        }

        private func drag(to locationInWindow: NSPoint) {
            guard let table, let model = view?.lineModel else { return }
            let point = table.convert(locationInWindow, from: nil)
            let hit = table.row(at: point)
            let row = hit >= 0 ? hit : point.y < 0 ? 0 : rows.count - 1
            guard case let .line(line) = block(at: row), let source = line.source else { return }
            model.dragLine(to: source)
        }

        private func indexRows(_ next: DiffTableView) {
            let blocks = next.document.blocks
            rows = next.hidesFileCards ? blocks.indices.filter { if case .file = blocks[$0] { false } else { true } } : Array(blocks.indices)
            hunkRows = rows.indices.filter { if case .hunk = blocks[rows[$0]] { true } else { false } }
            hunkMap = DiffHunkRows(blocks: rows.map { blocks[$0] })
            numberColumns = next.document.lines.contains { $0.oldNumber != nil } ? 2 : 1
        }

        private func block(at row: Int) -> DiffBlock? {
            guard let view, rows.indices.contains(row) else { return nil }
            return view.document.blocks[rows[row]]
        }

        private func scroll(_ direction: DiffHunkJump.Direction) {
            guard let table, let clip = table.enclosingScrollView?.contentView else { return }
            let top = table.row(at: NSPoint(x: 0, y: clip.bounds.minY + 1))
            let target: Int? = switch direction {
            case .next: hunkRows.first { $0 > top }
            case .previous: hunkRows.last { $0 < top }
            }
            guard let target else { return }
            clip.scroll(to: NSPoint(x: clip.bounds.minX, y: table.rect(ofRow: target).minY))
            table.enclosingScrollView?.reflectScrolledClipView(clip)
        }

        var hasHunks: Bool { !hunkRows.isEmpty }

        func numberOfRows(in tableView: NSTableView) -> Int {
            rows.count
        }

        func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
            guard case .hunk = block(at: row) else { return false }
            return true
        }

        func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
            false
        }

        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            guard let view, let block = block(at: row) else { return tableView.rowHeight }
            switch block {
            case let .line(line):
                guard let wrap else { return view.metrics.rowHeight }
                return wrap.height(forColumns: columns(of: line, tabWidth: view.metrics.tabWidth))
            case .hunk:
                return Metrics.Diff.hunkRow
            case .file:
                if let height = cardHeights[row] { return height }
                let height = measureCard(row)
                cardHeights[row] = height
                return height
            }
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let view, let block = block(at: row) else { return nil }
            switch block {
            case let .line(line):
                let cell = tableView.makeView(withIdentifier: DiffCellID.line, owner: self) as? DiffLineCell ?? DiffLineCell()
                cell.identifier = DiffCellID.line
                let source = view.lineModel == nil ? nil : line.source
                cell.configure(
                    line: line,
                    text: text(for: line),
                    font: font,
                    numberFont: numberFont,
                    numberWidth: numberWidth,
                    numberColumns: numberColumns,
                    source: source,
                    isSelected: source.map { view.lineState.selection.contains($0) } ?? false,
                    allowsTextSelection: view.lineModel == nil,
                    wrap: wrap
                )
                cell.onClick = { [weak self] click in
                    guard let source, let model = self?.view?.lineModel else { return }
                    model.selectLine(source, click)
                }
                cell.onDrag = { [weak self] location in self?.drag(to: location) }
                let blockIndex = rows[row]
                cell.menuProvider = { [weak self] in self?.menu(for: line, row: blockIndex, tableRow: row) }
                return cell
            case let .hunk(line):
                let content = DiffHunkHeader(text: line.text)
                let cell = tableView.makeView(withIdentifier: DiffCellID.hunk, owner: self) as? NSHostingView<DiffHunkHeader> ?? NSHostingView(rootView: content)
                cell.identifier = DiffCellID.hunk
                cell.rootView = content
                return cell
            case let .file(line, meta, additions, deletions):
                let content = DiffFileRowContent(header: line, meta: meta, additions: additions, deletions: deletions, showsRaw: view.showsRawDiff, toggleRaw: view.toggleRawDiff, visibleWidth: visibleWidth)
                let cell = tableView.makeView(withIdentifier: DiffCellID.file, owner: self) as? NSHostingView<DiffFileRowContent> ?? NSHostingView(rootView: content)
                cell.identifier = DiffCellID.file
                cell.rootView = content
                return cell
            }
        }

        private var visibleWidth: CGFloat {
            max(table?.enclosingScrollView?.contentView.bounds.width ?? 0, Metrics.Diff.minimumCardWidth)
        }

        @objc func visibleWidthChanged() {
            rewrap()
            guard abs(visibleWidth - measuredWidth) > 0.5 else { return }
            remeasureCards()
        }

        private func rewrap() {
            guard let table, view?.metrics.wrapsLines == true else { return }
            let next = wrapLayout
            guard next != wrap else { return }
            wrap = next
            guard !rows.isEmpty else { return }
            table.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: rows.indices))
            let visible = table.rows(in: table.visibleRect)
            guard visible.length > 0 else { return }
            table.reloadData(forRowIndexes: IndexSet(integersIn: visible.location..<(visible.location + visible.length)), columnIndexes: IndexSet(integer: 0))
            layoutHover()
        }

        private func columns(of line: DiffLine, tabWidth: Int) -> Int {
            if let cached = columnCounts[line.id] { return cached }
            let count = DiffTabs.columns(of: line.text, width: tabWidth)
            columnCounts[line.id] = count
            return count
        }

        private func remeasureCards() {
            guard let table, let view else { return }
            cardHeights = [:]
            let cards = IndexSet(rows.indices.filter { if case .file = view.document.blocks[rows[$0]] { true } else { false } })
            guard !cards.isEmpty else { return }
            table.noteHeightOfRows(withIndexesChanged: cards)
            table.reloadData(forRowIndexes: cards, columnIndexes: IndexSet(integer: 0))
        }

        func tableView(_ tableView: NSTableView, didAdd rowView: NSTableRowView, forRow row: Int) {
            guard hoveredHunk != nil else { return }
            raiseHover()
        }

        @objc func visibleBoundsChanged() {
            refreshHover()
        }

        func hover(at point: NSPoint?) {
            let next = point.flatMap(actionableHunk(at:))
            guard next != hoveredHunk else { return }
            hoveredHunk = next
            layoutHover()
        }

        private func refreshHover() {
            guard let table, let window = table.window else { return }
            let point = table.convert(window.mouseLocationOutsideOfEventStream, from: nil)
            hover(at: table.visibleRect.contains(point) ? point : nil)
            layoutHover()
        }

        private func actionableHunk(at point: NSPoint) -> Int? {
            guard let table else { return nil }
            if let host = actionsHost, !host.isHidden, host.frame.contains(point) { return hoveredHunk }
            guard let hunk = hunkMap.hunk(atRow: table.row(at: point)), hoverButtons(for: hunk) != nil else { return nil }
            return hunk
        }

        private func hoverButtons(for hunk: Int) -> [HunkHoverButton]? {
            guard let view, !view.actions.isEmpty, view.hunks.indices.contains(hunk) else { return nil }
            let selected = view.lineModel.map { $0.hasSelectedLines(inHunk: hunk) ? $0.selectedLineCount : 0 } ?? 0
            return HunkHoverButtons.make(actions: view.actions, hunk: hunk, selectedLines: selected, selectionHasChanges: view.lineState.hasChanges, isBusy: view.lineState.isBusy)
        }

        private func run(_ button: HunkHoverButton, hunk: Int) {
            guard let view, button.isEnabled, view.hunks.indices.contains(hunk) else { return }
            if button.appliesToLines {
                view.performLines(button.action)
            } else {
                view.perform(button.action, view.hunks[hunk])
            }
        }

        private func layoutHover() {
            guard let table, let hunk = hoveredHunk, let range = hunkMap.range(of: hunk), range.upperBound < table.numberOfRows, let buttons = hoverButtons(for: hunk) else {
                outline.isHidden = true
                actionsHost?.isHidden = true
                return
            }
            let visible = table.visibleRect
            let top = table.rect(ofRow: range.lowerBound).minY
            let block = NSRect(x: visible.minX, y: top, width: visible.width, height: table.rect(ofRow: range.upperBound).maxY - top)
            outline.frame = block
            outline.isHidden = false
            outline.needsDisplay = true
            let content = HunkHoverActions(buttons: buttons) { [weak self] button in self?.run(button, hunk: hunk) }
            let host = actionsHost ?? NSHostingView(rootView: content)
            host.rootView = content
            host.wantsLayer = true
            host.layer?.zPosition = 2
            actionsHost = host
            let size = host.fittingSize
            let inset = Metrics.Diff.hoverInset
            let offset = max(((Metrics.Diff.hunkRow - size.height) / 2).rounded(), 0)
            let y = min(max(block.minY, visible.minY) + offset, max(block.minY + offset, block.maxY - size.height - inset))
            host.frame = NSRect(x: block.maxX - size.width - Metrics.Spacing.m, y: y, width: size.width, height: size.height)
            host.isHidden = false
            raiseHover()
        }

        private func raiseHover() {
            guard let table else { return }
            for view in [outline as NSView] + (actionsHost.map { [$0] } ?? []) where table.subviews.last !== view || view.superview !== table {
                table.addSubview(view, positioned: .above, relativeTo: nil)
            }
        }

        private func measureCard(_ row: Int) -> CGFloat {
            guard let view, case let .file(line, meta, additions, deletions) = block(at: row) else { return Metrics.Row.list }
            let content = DiffFileRowContent(header: line, meta: meta, additions: additions, deletions: deletions, showsRaw: view.showsRawDiff, toggleRaw: view.toggleRawDiff, visibleWidth: visibleWidth)
            measuredWidth = visibleWidth
            let sizing = cardSizer ?? NSHostingController(rootView: content)
            sizing.rootView = content
            cardSizer = sizing
            return ceil(sizing.sizeThatFits(in: CGSize(width: visibleWidth, height: 10_000)).height)
        }

        private func text(for line: DiffLine) -> NSAttributedString {
            if let cached = attributed[line.id] { return cached }
            guard let view else { return NSAttributedString(string: line.text) }
            let metrics = view.metrics
            let result = DiffLineText.make(line, font: font, tabWidth: metrics.tabWidth, showsInvisibles: metrics.showsInvisibles, wrapLineHeight: metrics.wrapsLines ? metrics.lineHeight : nil)
            attributed[line.id] = result
            return result
        }

        private func menu(for line: DiffLine, row: Int, tableRow: Int) -> NSMenu? {
            let menu = NSMenu()
            menu.autoenablesItems = false
            if let hunk = hunkMap.hunk(atRow: tableRow), let buttons = hoverButtons(for: hunk) {
                for button in buttons {
                    let item = DiffMenuItem(title: button.title) { [weak self] in self?.run(button, hunk: hunk) }
                    item.isEnabled = button.isEnabled
                    item.toolTip = button.help
                    item.setAccessibilityIdentifier("diff.line.\(button.identifier)")
                    menu.addItem(item)
                }
                menu.addItem(.separator())
            }
            if let view, let model = view.menuModel,
               let location = model.editorLocation(file: fileSummary(above: row, in: view.document), oldLine: line.oldNumber, newLine: line.newNumber) {
                let item = DiffMenuItem(title: IntegrationFileMenu.editorTitle(model.editorName, line: location.line)) {
                    Task { await model.openInEditor(path: location.path, line: location.line) }
                }
                item.setAccessibilityIdentifier("diff.line.openInEditor")
                menu.addItem(item)
            }
            if let model = view?.menuModel {
                if let request = model.lineHistoryRequest(for: line) {
                    let item = DiffMenuItem(title: "Show Line History (\(request.lineDescription))") { model.showLineHistory(request) }
                    item.setAccessibilityIdentifier("diff.line.lineHistory")
                    menu.addItem(item)
                }
                if let request = model.hunkLineHistoryRequest(for: line) {
                    let item = DiffMenuItem(title: "Show Line History of Hunk (\(request.lineDescription))") { model.showLineHistory(request) }
                    item.setAccessibilityIdentifier("diff.line.hunkHistory")
                    menu.addItem(item)
                }
            }
            if menu.items.last?.isSeparatorItem == true { menu.removeItem(at: menu.items.count - 1) }
            return menu.items.isEmpty ? nil : menu
        }

        private func fileSummary(above row: Int, in document: DiffDocument) -> DiffFileSummary? {
            guard document.blocks.indices.contains(row) else { return nil }
            for index in stride(from: row, through: 0, by: -1) {
                if case let .file(header, meta, additions, deletions) = document.blocks[index] {
                    return DiffFileSummary(header: ([header] + meta).map(\.text), additions: additions, deletions: deletions)
                }
            }
            return nil
        }
    }
}

struct DiffHunkJump: Equatable {
    enum Direction: Equatable {
        case previous
        case next
    }

    let id: Int
    let direction: Direction
}

struct DiffWrapLayout: Equatable {
    let columns: Int
    let characterWidth: CGFloat
    let rowHeight: CGFloat
    let lineHeight: CGFloat

    func height(forColumns count: Int) -> CGFloat {
        rowHeight + CGFloat(DiffWrap.rows(columns: count, perRow: columns) - 1) * lineHeight
    }
}

struct DiffLineState: Equatable {
    let selection: DiffLineSelection
    let hasChanges: Bool
    let isBusy: Bool
}

private enum DiffCellID {
    static let column = NSUserInterfaceItemIdentifier("diff.column")
    static let line = NSUserInterfaceItemIdentifier("diff.lineCell")
    static let hunk = NSUserInterfaceItemIdentifier("diff.hunkCell")
    static let file = NSUserInterfaceItemIdentifier("diff.fileCell")
}

enum DiffLineText {
    static func make(_ line: DiffLine, font: NSFont, tabWidth: Int, showsInvisibles: Bool = false, wrapLineHeight: CGFloat? = nil) -> NSAttributedString {
        let expanded = DiffTabs.expand(line.text, changed: line.changed, width: tabWidth, marksInvisiblesAfter: showsInvisibles ? invisiblesStart(of: line) : nil)
        let string = expanded.text.isEmpty ? " " : expanded.text
        let color = line.kind == .meta ? Palette.Text.secondary.nsColor : Palette.Text.primary.nsColor
        let result = NSMutableAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
        let length = (string as NSString).length
        if let changed = expanded.changed, changed.upperBound <= length {
            let highlight = line.kind == .addition ? Palette.Diff.addedWord.nsColor : Palette.Diff.deletedWord.nsColor
            result.addAttribute(wrapLineHeight == nil ? .diffWordHighlight : .backgroundColor, value: highlight, range: NSRange(location: changed.lowerBound, length: changed.count))
        }
        if let wrapLineHeight {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byCharWrapping
            paragraph.minimumLineHeight = wrapLineHeight
            paragraph.maximumLineHeight = wrapLineHeight
            result.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: length))
        }
        let markColor = Palette.Text.tertiary.nsColor
        for mark in expanded.marks where mark < length {
            result.addAttribute(.foregroundColor, value: markColor, range: NSRange(location: mark, length: 1))
        }
        return result
    }

    static func invisiblesStart(of line: DiffLine) -> Int? {
        switch line.kind {
        case .addition, .deletion: 1
        case .context where line.text.hasPrefix("\\"): nil
        case .context: line.oldNumber == nil && line.newNumber != nil ? 0 : 1
        case .hunk, .meta: nil
        }
    }

    static func highlight(in text: NSAttributedString) -> (range: NSRange, color: NSColor)? {
        var found: (range: NSRange, color: NSColor)?
        text.enumerateAttribute(.diffWordHighlight, in: NSRange(location: 0, length: text.length)) { value, range, stop in
            guard let color = value as? NSColor else { return }
            found = (range, color)
            stop.pointee = true
        }
        return found
    }
}

extension NSAttributedString.Key {
    static let diffWordHighlight = NSAttributedString.Key("mork.diffWordHighlight")
}

struct DiffHunkHeader: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Metrics.Font.monoCaption)
            .foregroundStyle(Palette.Text.secondary.color)
            .lineLimit(1)
            .padding(.horizontal, Metrics.Spacing.m)
            .frame(height: Metrics.Diff.hunkRow)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.Diff.hunk.color)
    }
}

private final class DiffNSTableView: NSTableView {
    var onHover: ((NSPoint?) -> Void)?
    private var hoverArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        onHover?(convert(event.locationInWindow, from: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onHover?(convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onHover?(nil)
    }

    override func validateProposedFirstResponder(_ responder: NSResponder, for event: NSEvent?) -> Bool {
        true
    }
}

private final class DiffMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func run() {
        handler()
    }
}

struct DiffLineColors {
    let line: NSColor?
    let gutter: NSColor
    let number: NSColor

    init(kind: DiffLine.Kind) {
        switch kind {
        case .addition:
            line = Palette.Diff.addedLine.nsColor
            gutter = Palette.Diff.addedGutter.nsColor
            number = Palette.Status.added.ink.nsColor
        case .deletion:
            line = Palette.Diff.deletedLine.nsColor
            gutter = Palette.Diff.deletedGutter.nsColor
            number = Palette.Status.deleted.ink.nsColor
        default:
            line = nil
            gutter = Palette.Diff.gutter.nsColor
            number = Palette.Text.tertiary.nsColor
        }
    }
}

final class DiffLineCell: NSView {
    var onClick: ((LineClick) -> Void)?
    var onDrag: ((NSPoint) -> Void)?
    var menuProvider: (() -> NSMenu?)?
    private let content = NSTextField(labelWithString: "")
    private var line: DiffLine?
    private var numberWidth: CGFloat = 0
    private var numberColumns = 2
    private var numberFont = NSFont.monospacedSystemFont(ofSize: DiffMetrics.standard.numberFontSize, weight: .regular)
    private var isSelected = false
    private var isSelectable = false
    private var source: DiffLineID?
    private var word: (start: CGFloat, width: CGFloat, color: NSColor)?
    private var wrap: DiffWrapLayout?

    override init(frame: NSRect) {
        super.init(frame: frame)
        content.lineBreakMode = .byClipping
        content.maximumNumberOfLines = 1
        content.drawsBackground = false
        content.isBordered = false
        addSubview(content)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool { true }

    func configure(line: DiffLine, text: NSAttributedString, font: NSFont, numberFont: NSFont, numberWidth: CGFloat, numberColumns: Int = 2, source: DiffLineID?, isSelected: Bool, allowsTextSelection: Bool, wrap: DiffWrapLayout? = nil) {
        self.line = line
        self.wrap = wrap
        content.usesSingleLineMode = wrap == nil
        content.cell?.wraps = wrap != nil
        content.lineBreakMode = wrap == nil ? .byClipping : .byCharWrapping
        content.maximumNumberOfLines = wrap == nil ? 1 : 0
        self.numberWidth = numberWidth
        self.numberColumns = numberColumns
        self.numberFont = numberFont
        self.isSelected = isSelected
        self.source = source
        isSelectable = source != nil
        content.attributedStringValue = text
        word = wrap != nil ? nil : DiffLineText.highlight(in: text).map { found in
            let start = text.attributedSubstring(from: NSRange(location: 0, length: found.range.location)).size().width
            let end = text.attributedSubstring(from: NSRange(location: 0, length: NSMaxRange(found.range))).size().width
            return (start, end - start, found.color)
        }
        content.isSelectable = allowsTextSelection
        content.setAccessibilityElement(!isSelectable)
        if let source {
            setAccessibilityElement(true)
            setAccessibilityRole(.button)
            setAccessibilityLabel(line.text)
            setAccessibilityValue(isSelected ? "selected" : "")
            setAccessibilityIdentifier("diff.line.\(source.hunk).\(source.line)")
        } else {
            setAccessibilityElement(false)
            setAccessibilityIdentifier(nil)
        }
        needsLayout = true
        needsDisplay = true
    }

    func showSelection(_ selection: DiffLineSelection) {
        guard let source else { return }
        let selected = selection.contains(source)
        guard selected != isSelected else { return }
        isSelected = selected
        setAccessibilityValue(selected ? "selected" : "")
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        let gutter = numberWidth > 0 ? (numberWidth + Metrics.Diff.numberGap) * CGFloat(numberColumns) : 0
        let inset = Metrics.Diff.textInset
        if let wrap {
            let top = ((wrap.rowHeight - wrap.lineHeight) / 2).rounded(.down)
            content.frame = NSRect(x: gutter + inset, y: top, width: DiffWrap.fieldWidth(columns: wrap.columns, characterWidth: wrap.characterWidth), height: max(0, bounds.height - top))
            return
        }
        let height = content.intrinsicContentSize.height
        content.frame = NSRect(x: gutter + inset, y: (bounds.height - height) / 2, width: max(0, bounds.width - gutter - inset), height: height)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let line else { return }
        let colors = DiffLineColors(kind: line.kind)
        if let fill = colors.line {
            fill.setFill()
            bounds.fill()
        }
        if numberWidth > 0 {
            let gap = Metrics.Diff.numberGap
            let gutter = (numberWidth + gap) * CGFloat(numberColumns)
            colors.gutter.setFill()
            NSRect(x: 0, y: 0, width: gutter, height: bounds.height).fill()
            if numberColumns > 1 { drawNumber(line.oldNumber, right: numberWidth, color: colors.number) }
            drawNumber(line.newNumber, right: gutter - gap, color: colors.number)
        }
        if let word {
            word.color.setFill()
            let frame = content.frame
            let rect = NSRect(x: frame.minX + Metrics.Diff.textPadding + word.start, y: frame.minY, width: word.width, height: frame.height)
            NSBezierPath(roundedRect: rect, xRadius: Metrics.Radius.small, yRadius: Metrics.Radius.small).fill()
        }
        if isSelected {
            Palette.Accent.fill.nsColor.withAlphaComponent(Metrics.Diff.selectionOpacity).setFill()
            bounds.fill(using: .sourceOver)
            Palette.Accent.fill.nsColor.setFill()
            NSRect(x: 0, y: 0, width: Metrics.Diff.selectionBar, height: bounds.height).fill()
        }
    }

    private func drawNumber(_ value: Int?, right: CGFloat, color: NSColor) {
        guard let value else { return }
        let string = NSAttributedString(string: String(value), attributes: [.font: numberFont, .foregroundColor: color])
        let size = string.size()
        let height = wrap?.rowHeight ?? bounds.height
        string.draw(at: NSPoint(x: right - size.width, y: (height - size.height) / 2))
    }

    override func mouseDown(with event: NSEvent) {
        guard isSelectable else {
            super.mouseDown(with: event)
            return
        }
        let flags = event.modifierFlags
        onClick?(flags.contains(.shift) ? .extend : flags.contains(.command) ? .toggle : .replace)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isSelectable else {
            super.mouseDragged(with: event)
            return
        }
        superview?.autoscroll(with: event)
        onDrag?(event.locationInWindow)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        menuProvider?() ?? super.menu(for: event)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        if hit === content, isSelectable, !content.isSelectable { return self }
        guard hit === content, content.isSelectable, let event = NSApp.currentEvent, Self.opensContextMenu(event), menuProvider?() != nil else { return hit }
        return self
    }

    private static func opensContextMenu(_ event: NSEvent) -> Bool {
        event.type == .rightMouseDown || (event.type == .leftMouseDown && event.modifierFlags.contains(.control))
    }

    override func accessibilityPerformPress() -> Bool {
        guard isSelectable else { return false }
        onClick?(.replace)
        return true
    }
}

struct DiffFileRowContent: View {
    let header: DiffLine
    let meta: [DiffLine]
    let additions: Int
    let deletions: Int
    let showsRaw: Bool
    let toggleRaw: (() -> Void)?
    let visibleWidth: CGFloat

    var body: some View {
        DiffFileCard(header: header, meta: meta, additions: additions, deletions: deletions, showsRaw: showsRaw, toggleRaw: toggleRaw)
            .frame(width: visibleWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
