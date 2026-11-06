import AppKit
import SwiftUI

final class SidebarRowAnchorView: NSView {
    var selection: RepositoryViewModel.SidebarSelection?
    var trailingInset: CGFloat = 0
    weak var marks: SidebarSelectionMarks?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct SidebarRowAnchor: NSViewRepresentable {
    let selection: RepositoryViewModel.SidebarSelection
    let trailingInset: CGFloat
    let marks: SidebarSelectionMarks

    func makeNSView(context: Context) -> SidebarRowAnchorView {
        SidebarRowAnchorView()
    }

    func updateNSView(_ view: SidebarRowAnchorView, context: Context) {
        view.selection = selection
        view.trailingInset = trailingInset
        view.marks = marks
    }
}

enum SidebarDoubleClick {
    static func item(at location: NSPoint, clickCount: Int, hit: NSView?, marks: SidebarSelectionMarks) -> RepositoryViewModel.SidebarSelection? {
        guard clickCount == 2, let row = rowView(containing: hit, at: location), let anchor = anchor(in: row), anchor.marks === marks else { return nil }
        var active = anchor.bounds
        active.size.width -= anchor.trailingInset
        return active.contains(anchor.convert(location, from: nil)) ? anchor.selection : nil
    }

    private static func rowView(containing view: NSView?, at location: NSPoint) -> NSTableRowView? {
        var current = view
        while let candidate = current {
            if let row = candidate as? NSTableRowView { return row }
            if let table = candidate as? NSTableView {
                let row = table.row(at: table.convert(location, from: nil))
                return row >= 0 ? table.rowView(atRow: row, makeIfNecessary: false) : nil
            }
            current = candidate.superview
        }
        return nil
    }

    private static func anchor(in view: NSView) -> SidebarRowAnchorView? {
        (view as? SidebarRowAnchorView) ?? view.subviews.lazy.compactMap(anchor(in:)).first
    }
}

struct SidebarDoubleClickMonitor: NSViewRepresentable {
    let marks: SidebarSelectionMarks

    func makeNSView(context: Context) -> MonitorView {
        MonitorView(marks: marks)
    }

    func updateNSView(_ view: MonitorView, context: Context) {}

    final class MonitorView: NSView {
        private let marks: SidebarSelectionMarks
        private var monitor: Any?

        init(marks: SidebarSelectionMarks) {
            self.marks = marks
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { nil }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                MainActor.assumeIsolated { self?.handle(event) }
                return event
            }
        }

        private func handle(_ event: NSEvent) {
            guard let window, event.window === window, let frame = window.contentView?.superview else { return }
            let hit = frame.hitTest(frame.convert(event.locationInWindow, from: nil))
            guard let item = SidebarDoubleClick.item(at: event.locationInWindow, clickCount: event.clickCount, hit: hit, marks: marks) else { return }
            marks.onActivate?(item)
        }
    }
}
