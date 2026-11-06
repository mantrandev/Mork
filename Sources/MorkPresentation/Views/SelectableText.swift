import AppKit
import SwiftUI

struct SelectableText: NSViewRepresentable {
    let text: NSAttributedString
    var singleLine = false
    let identifier: String

    init(_ text: NSAttributedString, singleLine: Bool = false, identifier: String) {
        self.text = text
        self.singleLine = singleLine
        self.identifier = identifier
    }

    init(_ string: String, font: NSFont, color: NSColor = Palette.Text.primary.nsColor, singleLine: Bool = true, identifier: String) {
        self.init(NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color]), singleLine: singleLine, identifier: identifier)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(labelWithAttributedString: text)
        field.isSelectable = true
        field.allowsEditingTextAttributes = false
        field.maximumNumberOfLines = singleLine ? 1 : 0
        field.lineBreakMode = singleLine ? .byTruncatingTail : .byWordWrapping
        field.cell?.wraps = !singleLine
        field.cell?.truncatesLastVisibleLine = true
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.setContentHuggingPriority(.defaultHigh, for: .vertical)
        field.setAccessibilityIdentifier(identifier)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        if !field.attributedStringValue.isEqual(to: text) { field.attributedStringValue = text }
        if field.accessibilityIdentifier() != identifier { field.setAccessibilityIdentifier(identifier) }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView field: NSTextField, context: Context) -> CGSize? {
        guard let cell = field.cell else { return nil }
        let unbounded = CGFloat.greatestFiniteMagnitude
        if singleLine {
            let natural = cell.cellSize(forBounds: NSRect(x: 0, y: 0, width: unbounded, height: unbounded))
            let width = proposal.width.map { min($0, natural.width) } ?? natural.width
            return CGSize(width: ceil(width), height: ceil(natural.height))
        }
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? Metrics.TextLayout.fallbackWidth
        let size = cell.cellSize(forBounds: NSRect(x: 0, y: 0, width: width, height: unbounded))
        return CGSize(width: width, height: ceil(size.height))
    }
}
