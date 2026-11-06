import AppKit
import SwiftUI

struct PathLabel: NSViewRepresentable {
    enum Style {
        case split
        case plain
    }

    let path: String
    var style = Style.split
    var font = NSFont.systemFont(ofSize: Metrics.CommitDetails.fileFont)

    private static let paragraph: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingHead
        return style
    }()

    static func attributed(_ path: String, style: Style, font: NSFont, isDeleted: Bool = false) -> NSAttributedString {
        let nameColor = isDeleted ? Palette.Text.secondary.nsColor : Palette.Text.primary.nsColor
        var nameAttributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: nameColor, .paragraphStyle: paragraph]
        if isDeleted { nameAttributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        guard style == .split else {
            return NSAttributedString(string: path, attributes: nameAttributes)
        }
        nameAttributes[.font] = NSFont.systemFont(ofSize: font.pointSize, weight: .semibold)
        guard let slash = path.lastIndex(of: "/") else {
            return NSAttributedString(string: path, attributes: nameAttributes)
        }
        let result = NSMutableAttributedString(string: String(path[...slash]), attributes: [.font: font, .foregroundColor: Palette.Text.secondary.nsColor, .paragraphStyle: paragraph])
        result.append(NSAttributedString(string: String(path[path.index(after: slash)...]), attributes: nameAttributes))
        return result
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(labelWithString: "")
        field.maximumNumberOfLines = 1
        field.lineBreakMode = .byTruncatingHead
        field.cell?.truncatesLastVisibleLine = true
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.setAccessibilityElement(false)
        update(field)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        update(field)
    }

    private func update(_ field: NSTextField) {
        let text = Self.attributed(path, style: style, font: font)
        if !field.attributedStringValue.isEqual(to: text) { field.attributedStringValue = text }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView field: NSTextField, context: Context) -> CGSize? {
        let natural = field.attributedStringValue.size()
        let width = proposal.width.map { min($0, ceil(natural.width) + 2) } ?? ceil(natural.width) + 2
        return CGSize(width: width, height: ceil(natural.height))
    }
}
