import AppKit
import MorkDomain
import SwiftUI

struct ConsoleTable: NSViewRepresentable {
    enum Change: Equatable {
        case none
        case shift(dropped: Int, appended: Int)
        case reload
    }

    let records: [GitCommandRecord]
    let showsLessons: Bool
    let lesson: (GitCommandRecord) -> String?

    static func change(from old: [UUID], to new: [UUID]) -> Change {
        if old == new { return .none }
        guard let first = new.first else { return .reload }
        let dropped = old.firstIndex(of: first) ?? old.count
        let kept = old.count - dropped
        guard kept <= new.count, old[dropped...].elementsEqual(new.prefix(kept)) else { return .reload }
        return .shift(dropped: dropped, appended: new.count - kept)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let table = ConsoleTableView()
        table.onWidthChange = { [weak coordinator = context.coordinator] in coordinator?.rewrap() }
        table.headerView = nil
        table.style = .plain
        table.intercellSpacing = .zero
        table.usesAutomaticRowHeights = true
        table.selectionHighlightStyle = .none
        table.backgroundColor = .clear
        table.focusRingType = .none
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        let column = NSTableColumn(identifier: ConsoleRecordCell.identifier)
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.dataSource = context.coordinator
        table.delegate = context.coordinator
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.setAccessibilityIdentifier("console.list")
        context.coordinator.table = table
        context.coordinator.update(self)
        table.sizeLastColumnToFit()
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.update(self)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        weak var table: NSTableView?
        private var view: ConsoleTable?
        private var records: [GitCommandRecord] = []
        private var showsLessons = true
        private var expanded: Set<UUID> = []

        func update(_ next: ConsoleTable) {
            let previous = records
            let lessonsChanged = view != nil && showsLessons != next.showsLessons
            view = next
            records = next.records
            showsLessons = next.showsLessons
            guard let table else { return }
            let change = lessonsChanged ? .reload : ConsoleTable.change(from: previous.map(\.id), to: records.map(\.id))
            switch change {
            case .none:
                return
            case let .shift(dropped, appended):
                table.beginUpdates()
                if dropped > 0 { table.removeRows(at: IndexSet(integersIn: 0..<dropped), withAnimation: []) }
                if appended > 0 { table.insertRows(at: IndexSet(integersIn: (records.count - appended)..<records.count), withAnimation: []) }
                table.endUpdates()
            case .reload:
                table.reloadData()
            }
            if !expanded.isEmpty { expanded.formIntersection(records.map(\.id)) }
            if !lessonsChanged, let last = records.indices.last { table.scrollRowToVisible(last) }
        }

        func setExpanded(_ isExpanded: Bool, for id: UUID) {
            guard expanded.contains(id) != isExpanded else { return }
            if isExpanded { expanded.insert(id) } else { expanded.remove(id) }
            guard let table, let row = records.firstIndex(where: { $0.id == id }) else { return }
            if let cell = table.view(atColumn: 0, row: row, makeIfNecessary: false) as? ConsoleRecordCell {
                configure(cell, row: row)
            }
            table.noteHeightOfRows(withIndexesChanged: IndexSet(integer: row))
        }

        func rewrap() {
            guard let table, !records.isEmpty else { return }
            table.reloadData()
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            records.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let cell = tableView.makeView(withIdentifier: ConsoleRecordCell.identifier, owner: nil) as? ConsoleRecordCell ?? ConsoleRecordCell()
            configure(cell, row: row)
            return cell
        }

        func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
            false
        }

        private func configure(_ cell: ConsoleRecordCell, row: Int) {
            let record = records[row]
            let id = record.id
            let isExpanded = Binding(
                get: { [weak self] in self?.expanded.contains(id) ?? false },
                set: { [weak self] in self?.setExpanded($0, for: id) }
            )
            cell.show(RecordRow(record: record, lesson: view?.lesson(record), isExpanded: isExpanded), width: table?.bounds.width ?? .zero)
        }
    }
}

final class ConsoleRecordCell: NSTableCellView {
    static let identifier = NSUserInterfaceItemIdentifier("console.cell")

    private var host: NSHostingView<AnyView>?
    private(set) var record: GitCommandRecord?

    init() {
        super.init(frame: .zero)
        identifier = Self.identifier
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show(_ row: RecordRow, width: CGFloat) {
        record = row.record
        let padded = row.padding(EdgeInsets(top: Metrics.Spacing.xs, leading: Metrics.Spacing.m, bottom: Metrics.Spacing.xs, trailing: Metrics.Spacing.m))
        let content = width > .zero ? AnyView(padded.frame(width: width, alignment: .leading)) : AnyView(padded)
        if let host {
            host.rootView = content
            host.invalidateIntrinsicContentSize()
            return
        }
        let host = NSHostingView(rootView: content)
        host.translatesAutoresizingMaskIntoConstraints = false
        addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.trailingAnchor.constraint(equalTo: trailingAnchor),
            host.topAnchor.constraint(equalTo: topAnchor),
            host.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        self.host = host
    }
}

final class ConsoleTableView: NSTableView {
    var onWidthChange: (() -> Void)?
    private var laidOutWidth: CGFloat = .zero
    private var needsRewrap = false

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        guard newSize.width != laidOutWidth else { return }
        laidOutWidth = newSize.width
        guard numberOfRows > 0, !needsRewrap else { return }
        needsRewrap = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            needsRewrap = false
            onWidthChange?()
        }
    }
}
