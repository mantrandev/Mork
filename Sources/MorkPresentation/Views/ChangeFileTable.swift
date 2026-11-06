import AppKit
import MorkDomain
import SwiftUI

struct ChangeFileTable<MenuContent: View>: NSViewRepresentable {
    static var removeAnimation: NSTableView.AnimationOptions { [.slideDown, .effectFade] }
    static var insertAnimation: NSTableView.AnimationOptions { [.slideDown, .effectFade] }

    let changes: [FileChange]
    let rows: [FileListRow<FileChange>]
    let staged: Bool
    let animationTick: Int
    let selectedPath: String?
    let identifier: String
    let isLFS: (String) -> Bool
    let onSelect: (FileChange?) -> Void
    let onToggle: (FileChange) -> Void
    let onDoubleClick: (FileChange) -> Void
    @ViewBuilder let menu: (FileChange) -> MenuContent
    var selectedPaths: Set<String>? = nil
    var onSelection: (([FileListRow<FileChange>]) -> Void)? = nil
    var onDiscard: (() -> Void)? = nil
    var onPreview: ((_ isSingleFile: Bool) -> Void)? = nil
    var onClosePreview: (() -> Bool)? = nil
    var onToggleSelection: (([FileChange]) -> Void)? = nil
    var onToggleFolder: ((String) -> Void)? = nil
    var onToggleFolderStaging: ((String) -> Void)? = nil
    var onHover: ((FileChange?) -> Void)? = nil
    var showsLocation = false

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let table = ChangeTableView()
        table.headerView = showsLocation ? NSTableHeaderView(frame: NSRect(x: 0, y: 0, width: 0, height: Metrics.ChangeRow.tableHeader)) : nil
        table.allowsColumnReordering = false
        table.style = .plain
        table.intercellSpacing = .zero
        table.usesAutomaticRowHeights = false
        table.rowHeight = Metrics.Row.list
        table.allowsEmptySelection = true
        table.allowsMultipleSelection = true
        table.columnAutoresizingStyle = showsLocation ? .reverseSequentialColumnAutoresizingStyle : .uniformColumnAutoresizingStyle
        let column = NSTableColumn(identifier: ChangeFileCell.identifier)
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        if showsLocation {
            let location = NSTableColumn(identifier: ChangeLocationCell.identifier)
            Self.configureHeader(column, title: "Name", inset: Metrics.ChangeRow.leading, minimumWidth: Metrics.ChangeRow.minimumColumn)
            Self.configureHeader(location, title: "Location", inset: Metrics.Spacing.xs, minimumWidth: Metrics.ChangeRow.locationColumn)
            location.width = Metrics.ChangeRow.locationColumn
            table.addTableColumn(location)
        }
        table.dataSource = context.coordinator
        table.delegate = context.coordinator
        table.target = context.coordinator
        table.doubleAction = #selector(Coordinator.doubleClicked)
        table.discardSelection = { [weak coordinator = context.coordinator] in coordinator?.discardSelection() }
        table.previewSelection = { [weak coordinator = context.coordinator] in coordinator?.previewSelection() ?? false }
        table.closePreview = { [weak coordinator = context.coordinator] in coordinator?.closePreview() ?? false }
        table.toggleSelection = { [weak coordinator = context.coordinator] in coordinator?.toggleSelection() ?? false }
        table.menuProvider = { [weak coordinator = context.coordinator] row in coordinator?.menu(forRow: row) }
        table.expandSelectedFolder = { [weak coordinator = context.coordinator] in coordinator?.expandSelectedFolder($0) ?? false }
        table.hoverRow = { [weak coordinator = context.coordinator] row in coordinator?.hover(row: row) }
        table.setAccessibilityIdentifier(identifier)
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.drawsBackground = false
        context.coordinator.table = table
        context.coordinator.update(self)
        if !showsLocation { table.sizeLastColumnToFit() }
        return scroll
    }

    private static func configureHeader(_ column: NSTableColumn, title: String, inset: CGFloat, minimumWidth: CGFloat) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.firstLineHeadIndent = inset
        paragraph.lineBreakMode = .byTruncatingTail
        column.title = title
        column.headerCell.attributedStringValue = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: Metrics.FontSize.caption),
            .foregroundColor: Palette.Text.secondary.nsColor,
            .paragraphStyle: paragraph,
        ])
        column.minWidth = minimumWidth
        column.resizingMask = [.autoresizingMask, .userResizingMask]
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.update(self)
    }

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        weak var table: NSTableView?
        private var view: ChangeFileTable?
        private var rows: [FileListRow<FileChange>] = []
        private var isApplyingSelection = false

        func update(_ next: ChangeFileTable) {
            let previous = view
            view = next
            guard let table else { return }
            let old = rows
            if old != next.rows {
                rows = next.rows
                isApplyingSelection = true
                let diff = ChangeTableDiff(old: old.map(\.id), new: rows.map(\.id))
                let animates = previous.map { $0.animationTick != next.animationTick || $0.changes == next.changes } ?? false
                if let diff, animates {
                    table.beginUpdates()
                    table.removeRows(at: diff.removed, withAnimation: ChangeFileTable.removeAnimation)
                    table.insertRows(at: diff.inserted, withAnimation: ChangeFileTable.insertAnimation)
                    table.endUpdates()
                    reloadChangedRows(old: old, skipping: diff.inserted)
                } else if let diff, diff.isEmpty {
                    reloadChangedRows(old: old, skipping: [])
                } else {
                    table.reloadData()
                }
                isApplyingSelection = false
            } else if previous?.selectedPath == next.selectedPath, previous?.selectedPaths == next.selectedPaths, previous?.staged == next.staged {
                refreshVisibleCells()
                return
            }
            refreshVisibleCells()
            applySelection(next.selectedPaths ?? Set(next.selectedPath.map { [$0] } ?? []))
        }

        private func reloadChangedRows(old: [FileListRow<FileChange>], skipping inserted: IndexSet) {
            guard let table else { return }
            let before = Dictionary(old.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let changed = IndexSet(rows.indices.filter { !inserted.contains($0) && before[rows[$0].id] != rows[$0] })
            if !changed.isEmpty { table.reloadData(forRowIndexes: changed, columnIndexes: [0]) }
        }

        private func refreshVisibleCells() {
            guard let table else { return }
            let visible = table.rows(in: table.visibleRect)
            guard visible.length > 0 else { return }
            for row in visible.location..<(visible.location + visible.length) where rows.indices.contains(row) {
                configure(table.view(atColumn: 0, row: row, makeIfNecessary: false), row: rows[row])
            }
        }

        private func configure(_ cell: NSView?, row: FileListRow<FileChange>) {
            guard let view else { return }
            if let change = row.file {
                let shownPath = view.showsLocation ? FilePathParts(change.path).name : row.title
                let title = FilePathParts.displayText(path: shownPath, originalPath: change.originalPath)
                (cell as? ChangeFileCell)?.configure(
                    change,
                    title: title,
                    depth: row.depth,
                    staged: view.staged,
                    showsStageButton: !view.showsLocation,
                    isLFS: view.isLFS(change.path),
                    toggle: toggle(change)
                )
            } else if let path = row.folderPath {
                (cell as? ChangeFolderCell)?.configure(
                    title: row.title,
                    path: path,
                    depth: row.depth,
                    isExpanded: row.isExpanded,
                    staged: view.staged,
                    toggleExpanded: { [weak self] in self?.view?.onToggleFolder?(path) },
                    toggleStaging: { [weak self] in self?.view?.onToggleFolderStaging?(path) }
                )
            }
        }

        private func applySelection(_ ids: Set<String>) {
            guard let table else { return }
            let indexes = IndexSet(rows.indices.filter { ids.contains(rows[$0].id) })
            guard table.selectedRowIndexes != indexes else { return }
            isApplyingSelection = true
            table.selectRowIndexes(indexes, byExtendingSelection: false)
            if let row = indexes.first { table.scrollRowToVisible(row) }
            isApplyingSelection = false
        }

        func discardSelection() {
            guard view?.staged == false, table?.selectedRowIndexes.isEmpty == false else { return }
            view?.onDiscard?()
        }

        func previewSelection() -> Bool {
            guard let onPreview = view?.onPreview, let table else { return false }
            let files = table.selectedRowIndexes.filter { file(at: $0) != nil }
            guard !files.isEmpty else { return false }
            onPreview(files.count == 1)
            return true
        }

        func expandSelectedFolder(_ expanded: Bool) -> Bool {
            guard let table, table.selectedRowIndexes.count == 1, rows.indices.contains(table.selectedRow),
                  let path = rows[table.selectedRow].folderPath else { return false }
            if rows[table.selectedRow].isExpanded != expanded { view?.onToggleFolder?(path) }
            return true
        }

        func closePreview() -> Bool {
            view?.onClosePreview?() ?? false
        }

        func toggleSelection() -> Bool {
            guard let table, let view, let onToggleSelection = view.onToggleSelection else { return false }
            let ids = Set(table.selectedRowIndexes.compactMap { rows.indices.contains($0) ? rows[$0].id : nil })
            let selected = FileList.files(view.changes, matching: ids, path: \.path)
            guard !selected.isEmpty else { return false }
            onToggleSelection(selected)
            return true
        }

        private func toggle(_ change: FileChange) -> () -> Void {
            { [weak self] in self?.view?.onToggle(change) }
        }

        func menu(forRow row: Int) -> NSMenu? {
            guard let view, rows.indices.contains(row) else { return nil }
            if let path = rows[row].folderPath {
                let item = NSMenuItem(title: view.staged ? "Unstage Folder" : "Stage Folder", action: #selector(folderStagingChosen(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = path
                let menu = NSMenu()
                menu.addItem(item)
                return menu
            }
            guard let change = rows[row].file else { return nil }
            if #available(macOS 15.0, *) {
                return NSHostingMenu(rootView: view.menu(change))
            }
            return nil
        }

        @objc private func folderStagingChosen(_ item: NSMenuItem) {
            guard let path = item.representedObject as? String else { return }
            view?.onToggleFolderStaging?(path)
        }

        @objc func doubleClicked() {
            guard let table, rows.indices.contains(table.clickedRow) else { return }
            let row = rows[table.clickedRow]
            if let change = row.file {
                view?.onDoubleClick(change)
            } else if let path = row.folderPath {
                view?.onToggleFolder?(path)
            }
        }

        private func file(at row: Int) -> FileChange? {
            rows.indices.contains(row) ? rows[row].file : nil
        }

        func hover(row: Int) {
            view?.onHover?(file(at: row))
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            rows.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard rows.indices.contains(row) else { return nil }
            if tableColumn?.identifier == ChangeLocationCell.identifier {
                let cell = tableView.makeView(withIdentifier: ChangeLocationCell.identifier, owner: nil) as? ChangeLocationCell ?? ChangeLocationCell()
                cell.configure(location: FilePathParts(rows[row].file?.path ?? "").location)
                return cell
            }
            let cell: NSView = rows[row].file == nil
                ? tableView.makeView(withIdentifier: ChangeFolderCell.identifier, owner: nil) as? ChangeFolderCell ?? ChangeFolderCell()
                : tableView.makeView(withIdentifier: ChangeFileCell.identifier, owner: nil) as? ChangeFileCell ?? ChangeFileCell()
            configure(cell, row: rows[row])
            return cell
        }

        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            let rowView = AccentSelectionRowView.make(in: tableView)
            rowView.isHovered = (tableView as? ChangeTableView)?.hoveredRow == row
            return rowView
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !isApplyingSelection, let table else { return }
            let selected = table.selectedRowIndexes.compactMap { rows.indices.contains($0) ? rows[$0] : nil }
            view?.onSelection?(selected)
            view?.onSelect(file(at: table.selectedRow) ?? selected.lazy.compactMap(\.file).first)
        }
    }
}

final class ChangeTableView: NSTableView {
    var menuProvider: ((Int) -> NSMenu?)?
    var discardSelection: (() -> Void)?
    var previewSelection: (() -> Bool)?
    var closePreview: (() -> Bool)?
    var toggleSelection: (() -> Bool)?
    var expandSelectedFolder: ((Bool) -> Bool)?
    var hoverRow: ((Int) -> Void)?
    private(set) var hoveredRow = -1
    private var hoverArea: NSTrackingArea?

    override func validateProposedFirstResponder(_ responder: NSResponder, for event: NSEvent?) -> Bool {
        responder is InlineSymbolButton || super.validateProposedFirstResponder(responder, for: event)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        hover(row(at: convert(event.locationInWindow, from: nil)))
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        hover(-1)
    }

    private func hover(_ row: Int) {
        guard row != hoveredRow else { return }
        setHovered(false, row: hoveredRow)
        hoveredRow = row
        setHovered(true, row: row)
        hoverRow?(row)
    }

    private func setHovered(_ hovered: Bool, row: Int) {
        guard row >= 0, row < numberOfRows else { return }
        (rowView(atRow: row, makeIfNecessary: false) as? AccentSelectionRowView)?.isHovered = hovered
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.isEmpty, event.charactersIgnoringModifiers == " ", previewSelection?() == true {
            return
        }
        if modifiers.subtracting([.numericPad, .function]).isEmpty, let arrow = event.specialKey, arrow == .leftArrow || arrow == .rightArrow,
           expandSelectedFolder?(arrow == .rightArrow) == true {
            return
        }
        if Self.isPlainReturn(event), event.isARepeat || toggleSelection?() == true {
            return
        }
        super.keyDown(with: event)
    }

    private static func isPlainReturn(_ event: NSEvent) -> Bool {
        event.modifierFlags.intersection([.shift, .control, .option, .command]).isEmpty
            && ["\r", "\u{3}"].contains(event.charactersIgnoringModifiers)
    }

    override func cancelOperation(_ sender: Any?) {
        if closePreview?() == true { return }
        super.cancelOperation(sender)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if window?.firstResponder === self,
           event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command, .shift],
           event.charactersIgnoringModifiers?.lowercased() == "d" {
            discardSelection?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        takeKeyboardFocus()
        super.mouseDown(with: event)
    }

    func takeKeyboardFocus() {
        if window?.firstResponder !== self { window?.makeFirstResponder(self) }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let row = row(at: convert(event.locationInWindow, from: nil))
        if row >= 0, !selectedRowIndexes.contains(row) {
            selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
        takeKeyboardFocus()
        return row >= 0 ? menuProvider?(row) : nil
    }
}

final class ChangeFileCell: NSView {
    static let identifier = NSUserInterfaceItemIdentifier("changes.cell")

    private let badge = StatusBadgeView()
    private let icon = NSImageView()
    private let path = NSTextField(labelWithString: "")
    private var conflict: NSTextField?
    private var lfs: NSTextField?
    private let button = InlineSymbolButton()
    private var change: FileChange?
    private var title = ""
    private var depth = 0
    private var staged = false
    private var showsStageButton = true
    private var isLFS = false
    private var toggle: () -> Void = {}

    init() {
        super.init(frame: .zero)
        identifier = Self.identifier
        icon.setAccessibilityElement(false)
        path.lineBreakMode = .byTruncatingHead
        path.cell?.truncatesLastVisibleLine = true
        path.setAccessibilityElement(false)
        button.onPress = { [weak self] in self?.toggle() }
        [badge, icon, path, button].forEach(addSubview)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(_ change: FileChange, title: String, depth: Int, staged: Bool, showsStageButton: Bool, isLFS: Bool, toggle: @escaping () -> Void) {
        self.toggle = toggle
        guard change != self.change || title != self.title || depth != self.depth || staged != self.staged || showsStageButton != self.showsStageButton || isLFS != self.isLFS else { return }
        self.change = change
        self.title = title
        self.depth = depth
        self.staged = staged
        self.showsStageButton = showsStageButton
        self.isLFS = isLFS
        let letter: Character = change.isConflicted ? "!" : change.isIgnored ? "I" : staged ? change.index : change.worktree
        let text = FilePathParts.displayText(path: change.path, originalPath: change.originalPath)
        badge.letter = letter
        icon.image = FileIconCache.icon(forExtension: FilePathParts(change.path).fileExtension)
        path.attributedStringValue = PathLabel.attributed(title, style: .split, font: .systemFont(ofSize: Metrics.FontSize.title), isDeleted: letter == "D")
        if change.isConflicted {
            conflictLabel().isHidden = false
        } else {
            conflict?.isHidden = true
        }
        if isLFS {
            let label = lfsLabel()
            label.isHidden = false
            label.setAccessibilityIdentifier("lfsBadge.\(change.path)")
        } else {
            lfs?.isHidden = true
        }
        button.symbolName = staged ? "minus.circle" : "plus.circle"
        button.toolTip = staged ? "Unstage (git restore --staged)" : change.isIgnored ? "Stage (git add --force)" : "Stage (git add)"
        button.setAccessibilityLabel(staged ? "Unstage" : "Stage")
        button.isHidden = !showsStageButton
        button.setAccessibilityIdentifier(showsStageButton ? "\(staged ? "unstage" : "stage").\(change.path)" : "")
        toolTip = text
        setAccessibilityIdentifier("\(staged ? "staged" : "unstaged").\(change.path)")
        setAccessibilityLabel(text)
        needsLayout = true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyBorderColor()
    }

    private func applyBorderColor() {
        guard let lfs else { return }
        effectiveAppearance.performAsCurrentDrawingAppearance {
            lfs.layer?.borderColor = Palette.Surface.borderStrong.nsColor.cgColor
        }
    }

    private func conflictLabel() -> NSTextField {
        if let conflict { return conflict }
        let label = NSTextField(labelWithString: "conflict")
        label.font = .systemFont(ofSize: Metrics.FontSize.caption, weight: .semibold)
        label.textColor = Palette.Status.conflict.ink.nsColor
        label.setAccessibilityElement(false)
        addSubview(label)
        conflict = label
        return label
    }

    private func lfsLabel() -> NSTextField {
        if let lfs { return lfs }
        let label = NSTextField(labelWithString: "LFS")
        label.font = .systemFont(ofSize: Metrics.FontSize.label, weight: .semibold)
        label.textColor = Palette.Text.secondary.nsColor
        label.alignment = .center
        label.wantsLayer = true
        label.layer?.cornerRadius = Metrics.Radius.badge
        label.layer?.borderWidth = 1
        label.toolTip = "Stored with Git LFS (filter=lfs in .gitattributes)"
        label.setAccessibilityLabel("Git LFS")
        addSubview(label)
        lfs = label
        applyBorderColor()
        return label
    }

    override func layout() {
        super.layout()
        let height = bounds.height
        let column = Metrics.Icon.column
        let gap = Metrics.ChangeRow.gap
        func centered(_ viewHeight: CGFloat) -> CGFloat { ((height - viewHeight) / 2).rounded() }
        let target = Metrics.HitTarget.inline
        var x = Metrics.ChangeRow.leading + CGFloat(depth) * Metrics.Indent.level
        badge.frame = NSRect(x: x, y: centered(column), width: column, height: column)
        x += column + gap
        icon.frame = NSRect(x: x, y: centered(column), width: column, height: column)
        x += column + gap
        var right = bounds.width - Metrics.Spacing.s
        if !button.isHidden {
            button.frame = NSRect(x: right - target, y: centered(target), width: target, height: target)
            right -= target + gap
        }
        if let lfs, !lfs.isHidden {
            let width = ceil(lfs.intrinsicContentSize.width) + Metrics.Spacing.xs * 2
            let badgeHeight = Metrics.LineHeight.caption
            lfs.frame = NSRect(x: right - width, y: centered(badgeHeight), width: width, height: badgeHeight)
            right -= width + gap
        }
        if let conflict, !conflict.isHidden {
            let size = conflict.intrinsicContentSize
            conflict.frame = NSRect(x: right - ceil(size.width), y: centered(size.height), width: ceil(size.width), height: size.height)
            right -= ceil(size.width) + gap
        }
        let pathHeight = path.intrinsicContentSize.height
        path.frame = NSRect(x: x, y: centered(pathHeight), width: max(right - x, 0), height: pathHeight)
    }
}

final class ChangeLocationCell: NSView {
    static let identifier = NSUserInterfaceItemIdentifier("changes.locationCell")

    private let label = NSTextField(labelWithString: "")

    init() {
        super.init(frame: .zero)
        identifier = Self.identifier
        label.font = .systemFont(ofSize: Metrics.FontSize.body)
        label.textColor = Palette.Text.secondary.nsColor
        label.lineBreakMode = .byTruncatingHead
        label.cell?.truncatesLastVisibleLine = true
        label.setAccessibilityElement(false)
        addSubview(label)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(location: String) {
        guard location != label.stringValue else { return }
        label.stringValue = location
        toolTip = location.isEmpty ? nil : location
    }

    override func layout() {
        super.layout()
        let height = label.intrinsicContentSize.height
        let inset = Metrics.Spacing.xs
        label.frame = NSRect(x: inset, y: ((bounds.height - height) / 2).rounded(), width: max(bounds.width - inset * 2, 0), height: height)
    }
}

final class ChangeFolderCell: NSView {
    static let identifier = NSUserInterfaceItemIdentifier("changes.folderCell")

    private let disclosure = NSButton()
    private let icon = NSImageView()
    private let name = NSTextField(labelWithString: "")
    private let button = InlineSymbolButton()
    private var depth = 0
    private var shown: (title: String, path: String, isExpanded: Bool, staged: Bool)?
    private var toggleExpanded: () -> Void = {}
    private var toggleStaging: () -> Void = {}

    init() {
        super.init(frame: .zero)
        identifier = Self.identifier
        disclosure.isBordered = false
        disclosure.imagePosition = .imageOnly
        disclosure.contentTintColor = Palette.Text.secondary.nsColor
        disclosure.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: Metrics.Icon.disclosure, weight: .semibold)
        disclosure.target = self
        disclosure.action = #selector(disclosureClicked)
        icon.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        icon.contentTintColor = Palette.Text.secondary.nsColor
        icon.setAccessibilityElement(false)
        name.font = .systemFont(ofSize: Metrics.FontSize.title)
        name.textColor = Palette.Text.primary.nsColor
        name.lineBreakMode = .byTruncatingHead
        name.cell?.truncatesLastVisibleLine = true
        name.setAccessibilityElement(false)
        button.onPress = { [weak self] in self?.toggleStaging() }
        [disclosure, icon, name, button].forEach(addSubview)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(title: String, path: String, depth: Int, isExpanded: Bool, staged: Bool, toggleExpanded: @escaping () -> Void, toggleStaging: @escaping () -> Void) {
        self.toggleExpanded = toggleExpanded
        self.toggleStaging = toggleStaging
        if let shown, shown == (title, path, isExpanded, staged), self.depth == depth { return }
        shown = (title, path, isExpanded, staged)
        self.depth = depth
        name.stringValue = title
        disclosure.image = NSImage(systemSymbolName: isExpanded ? "chevron.down" : "chevron.right", accessibilityDescription: isExpanded ? "Collapse" : "Expand")
        disclosure.setAccessibilityLabel(isExpanded ? "Collapse" : "Expand")
        disclosure.setAccessibilityIdentifier("\(staged ? "staged" : "unstaged")FolderToggle.\(path)")
        button.symbolName = staged ? "minus.circle" : "plus.circle"
        button.toolTip = staged ? "Unstage every file in this folder (git restore --staged)" : "Stage every file in this folder (git add)"
        button.setAccessibilityLabel(staged ? "Unstage Folder" : "Stage Folder")
        button.setAccessibilityIdentifier("\(staged ? "unstageFolder" : "stageFolder").\(path)")
        toolTip = path
        setAccessibilityLabel(path)
        setAccessibilityIdentifier("\(staged ? "staged" : "unstaged")Folder.\(path)")
        needsLayout = true
    }

    @objc private func disclosureClicked() {
        toggleExpanded()
    }

    override func layout() {
        super.layout()
        let height = bounds.height
        let column = Metrics.Icon.column
        let gap = Metrics.ChangeRow.gap
        let target = Metrics.HitTarget.inline
        func centered(_ viewHeight: CGFloat) -> CGFloat { ((height - viewHeight) / 2).rounded() }
        let x = Metrics.ChangeRow.leading + CGFloat(depth) * Metrics.Indent.level
        disclosure.frame = NSRect(x: x - Metrics.Indent.disclosure, y: 0, width: Metrics.Indent.disclosure, height: height)
        icon.frame = NSRect(x: x, y: centered(column), width: column, height: column)
        let right = bounds.width - Metrics.Spacing.s
        button.frame = NSRect(x: right - target, y: centered(target), width: target, height: target)
        let nameX = x + column + gap
        let nameHeight = name.intrinsicContentSize.height
        name.frame = NSRect(x: nameX, y: centered(nameHeight), width: max(right - target - gap - nameX, 0), height: nameHeight)
    }
}
