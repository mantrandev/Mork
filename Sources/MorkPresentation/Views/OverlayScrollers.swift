import AppKit
import SwiftUI

extension View {
    func overlayScrollers(hidesFocusRing: Bool = false) -> some View {
        background(OverlayScrollersAnchor(hidesFocusRing: hidesFocusRing))
    }
}

private struct OverlayScrollersAnchor: NSViewRepresentable {
    let hidesFocusRing: Bool

    func makeNSView(context: Context) -> AnchorView {
        let view = AnchorView()
        view.hidesFocusRing = hidesFocusRing
        return view
    }

    func updateNSView(_ view: AnchorView, context: Context) {
        view.hidesFocusRing = hidesFocusRing
        view.scheduleApply()
    }

    final class AnchorView: NSView {
        var hidesFocusRing = false
        private var scrollViews: [WeakScrollView] = []
        private var watchers: [NSKeyValueObservation] = []
        private var observer: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else {
                if let observer { NotificationCenter.default.removeObserver(observer) }
                observer = nil
                return
            }
            if observer == nil {
                observer = NotificationCenter.default.addObserver(forName: NSScroller.preferredScrollerStyleDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.scheduleApply() }
                }
            }
            scheduleApply()
        }

        func scheduleApply() {
            DispatchQueue.main.async { [weak self] in self?.apply() }
        }

        private func apply() {
            var targets = scrollViews.compactMap(\.view)
            if targets.isEmpty {
                targets = findScrollViews()
                scrollViews = targets.map(WeakScrollView.init)
                watchers = targets.flatMap(watch)
            }
            for scroll in targets {
                if !(scroll.verticalScroller is TracklessScroller) { scroll.verticalScroller = TracklessScroller() }
                if hidesFocusRing { scroll.focusRingType = .none }
                if scroll.scrollerStyle != .overlay { scroll.scrollerStyle = .overlay }
                if !scroll.autohidesScrollers { scroll.autohidesScrollers = true }
            }
        }

        private func watch(_ scroll: NSScrollView) -> [NSKeyValueObservation] {
            [
                scroll.observe(\.scrollerStyle) { [weak self] scroll, _ in
                    MainActor.assumeIsolated { if scroll.scrollerStyle != .overlay { scroll.scrollerStyle = .overlay } }
                },
                scroll.observe(\.verticalScroller) { [weak self] scroll, _ in
                    MainActor.assumeIsolated { if !(scroll.verticalScroller is TracklessScroller) { self?.scheduleApply() } }
                }
            ]
        }

        private func findScrollViews() -> [NSScrollView] {
            guard window != nil else { return [] }
            let center = convert(NSPoint(x: bounds.midX, y: bounds.midY), to: nil)
            var ancestor = superview
            for _ in 0..<6 {
                guard let current = ancestor else { return [] }
                let matches = Self.scrollViews(in: current, containing: center, excluding: self)
                if !matches.isEmpty { return matches }
                ancestor = current.superview
            }
            return []
        }

        private static func scrollViews(in view: NSView, containing point: NSPoint, excluding anchor: NSView) -> [NSScrollView] {
            view.subviews.filter { $0 !== anchor }.flatMap { child -> [NSScrollView] in
                if let scroll = child as? NSScrollView {
                    return scroll.convert(scroll.bounds, to: nil).contains(point) ? [scroll] : []
                }
                return scrollViews(in: child, containing: point, excluding: anchor)
            }
        }
    }
}

private struct WeakScrollView {
    weak var view: NSScrollView?

    init(_ view: NSScrollView) {
        self.view = view
    }
}

final class TracklessScroller: NSScroller {
    override class var isCompatibleWithOverlayScrollers: Bool { true }

    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {}
}
