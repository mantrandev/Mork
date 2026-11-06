import AppKit
import MorkDomain
import SwiftUI

extension TabColor {
    var swatch: NSColor {
        switch self {
        case .red: .systemRed
        case .orange: .systemOrange
        case .yellow: .systemYellow
        case .green: .systemGreen
        case .blue: .systemBlue
        case .purple: .systemPurple
        case .gray: .systemGray
        }
    }
}

final class TabColorMenuView: NSView {
    static let diameter: CGFloat = 16
    static let spacing: CGFloat = 10
    static let leading: CGFloat = 22

    private let selected: TabColor?
    private let onSelect: (TabColor?) -> Void
    private var hovered: TabColor?

    init(selected: TabColor?, onSelect: @escaping (TabColor?) -> Void) {
        self.selected = selected
        self.onSelect = onSelect
        let width = Self.leading * 2 + CGFloat(TabColor.allCases.count) * (Self.diameter + Self.spacing) - Self.spacing
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: Self.diameter + 14))
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Tab Color")
        setAccessibilityIdentifier("tabMenu.colors")
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func rect(for index: Int) -> NSRect {
        NSRect(x: Self.leading + CGFloat(index) * (Self.diameter + Self.spacing), y: ((bounds.height - Self.diameter) / 2).rounded(), width: Self.diameter, height: Self.diameter)
    }

    private func color(at point: NSPoint) -> TabColor? {
        TabColor.allCases.indices.first { rect(for: $0).insetBy(dx: -Self.spacing / 2, dy: -4).contains(point) }.map { TabColor.allCases[$0] }
    }

    override func draw(_ dirtyRect: NSRect) {
        for (index, color) in TabColor.allCases.enumerated() {
            let circle = NSBezierPath(ovalIn: rect(for: index))
            color.swatch.withAlphaComponent(0.85).setFill()
            circle.fill()
            Palette.Surface.border.nsColor.setStroke()
            circle.lineWidth = Metrics.Line.hairline
            circle.stroke()
            if color == selected || color == hovered {
                let ring = NSBezierPath(ovalIn: rect(for: index).insetBy(dx: -Metrics.Control.focusRing, dy: -Metrics.Control.focusRing))
                ring.lineWidth = Metrics.Graph.ringLineWidth
                (color == selected ? Palette.Text.primary.nsColor : Palette.Text.secondary.nsColor).setStroke()
                ring.stroke()
            }
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let next = color(at: convert(event.locationInWindow, from: nil))
        guard next != hovered else { return }
        hovered = next
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hovered = nil
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let picked = color(at: convert(event.locationInWindow, from: nil)) else { return }
        onSelect(picked == selected ? nil : picked)
        enclosingMenuItem?.menu?.cancelTracking()
    }
}

struct RenameTabSheet: View {
    let app: AppViewModel
    let tab: RepositoryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""

    var body: some View {
        DialogScaffold(kind: .form, glyph: "pencil", title: "Rename Tab", message: "Leave it empty to show the folder name “\(tab.name)”.") {
            DialogTextField(placeholder: tab.name, text: $title, identifier: "renameTab.field", onSubmit: save)
        } buttons: {
            DialogCancelButton { dismiss() }
            DialogConfirmButton(title: "Rename", identifier: "renameTab.save", action: save)
        }
        .onAppear { title = app.appearance(of: tab).title ?? "" }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("renameTab.sheet")
    }

    private func save() {
        app.renameTab(tab, to: title)
        dismiss()
    }
}
