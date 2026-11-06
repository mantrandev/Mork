import AppKit
import SwiftUI

struct SidebarWindowFrame: NSViewRepresentable {
    func makeNSView(context: Context) -> FrameView {
        let view = FrameView()
        view.identifier = NSUserInterfaceItemIdentifier("sidebar.windowFrame")
        view.updateBorder()
        return view
    }

    func updateNSView(_ view: FrameView, context: Context) {
        view.updateBorder()
    }

    final class FrameView: NSView {
        private let card = NSView()
        private var cardWidth: CGFloat = 0

        override init(frame: NSRect) {
            super.init(frame: frame)
            card.wantsLayer = true
            card.layer?.cornerRadius = Metrics.Sidebar.windowRadius
            card.layer?.cornerCurve = .continuous
            card.layer?.masksToBounds = true
            card.layer?.borderWidth = Metrics.Sidebar.windowBorder
            addSubview(card)
        }

        required init?(coder: NSCoder) { nil }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func setFrameOrigin(_ newOrigin: NSPoint) {
            super.setFrameOrigin(newOrigin)
            placeCard()
        }

        override func setFrameSize(_ newSize: NSSize) {
            super.setFrameSize(newSize)
            placeCard()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            placeCard()
        }

        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            updateBorder()
        }

        func updateBorder() {
            effectiveAppearance.performAsCurrentDrawingAppearance {
                card.layer?.backgroundColor = Palette.Surface.sidebar.nsColor.cgColor
                card.layer?.borderColor = Palette.Surface.border.nsColor.cgColor
            }
        }

        private func placeCard() {
            let isCutByWindowEdge = window != nil && convert(bounds, to: nil).minX <= Metrics.Line.hairline / 2
            if !isCutByWindowEdge || cardWidth < bounds.width {
                cardWidth = bounds.width
            }
            card.frame = NSRect(x: bounds.width - cardWidth, y: 0, width: cardWidth, height: bounds.height)
        }
    }
}
