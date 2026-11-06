import AppKit
import SwiftUI

struct SearchField: View {
    let prompt: String
    @Binding var text: String
    let identifier: String
    @State private var isFocused = false

    var body: some View {
        HStack(spacing: Metrics.Spacing.xs + Metrics.Spacing.xxs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: Metrics.Control.fieldGlyph))
                .foregroundStyle(Palette.Text.tertiary.color)
                .accessibilityHidden(true)
            SearchTextField(prompt: prompt, text: $text, identifier: identifier, isFocused: $isFocused)
        }
        .padding(.horizontal, Metrics.Spacing.s)
        .frame(height: Metrics.Control.searchField)
        .fieldChrome(isFocused: isFocused)
    }
}

struct FieldChrome: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous)
        content
            .background(Palette.Surface.window.color, in: shape)
            .overlay(shape.strokeBorder(Palette.Surface.borderStrong.color, lineWidth: Metrics.Line.hairline))
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: Metrics.Radius.control + Metrics.Control.focusRing, style: .continuous)
                        .strokeBorder(Palette.Accent.glow.color.opacity(Palette.Ink.focusRing), lineWidth: Metrics.Control.focusRing)
                        .padding(-Metrics.Control.focusRing)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
    }
}

extension View {
    func fieldChrome(isFocused: Bool) -> some View {
        modifier(FieldChrome(isFocused: isFocused))
    }
}

private struct SearchTextField: NSViewRepresentable {
    let prompt: String
    @Binding var text: String
    let identifier: String
    @Binding var isFocused: Bool

    func makeNSView(context: Context) -> ClearEditingSearchField {
        let field = ClearEditingSearchField()
        field.placeholderAttributedString = NSAttributedString(string: prompt, attributes: [
            .font: NSFont.systemFont(ofSize: Metrics.FontSize.body),
            .foregroundColor: Palette.Text.tertiary.nsColor
        ])
        field.placeholderString = prompt
        field.font = .systemFont(ofSize: Metrics.FontSize.body)
        field.textColor = Palette.Text.primary.nsColor
        field.isBezeled = false
        field.isBordered = false
        field.drawsBackground = false
        field.backgroundColor = .clear
        field.focusRingType = .none
        (field.cell as? NSSearchFieldCell)?.searchButtonCell = nil
        field.sendsSearchStringImmediately = true
        field.delegate = context.coordinator
        field.onFocusChange = { [coordinator = context.coordinator] in coordinator.focusChanged($0) }
        field.setAccessibilityIdentifier(identifier)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ field: ClearEditingSearchField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.isFocused = $isFocused
        if field.stringValue != text { field.stringValue = text }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused)
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var text: Binding<String>
        var isFocused: Binding<Bool>

        init(text: Binding<String>, isFocused: Binding<Bool>) {
            self.text = text
            self.isFocused = isFocused
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            text.wrappedValue = field.stringValue
        }

        func focusChanged(_ focused: Bool) {
            guard isFocused.wrappedValue != focused else { return }
            isFocused.wrappedValue = focused
        }
    }
}

final class ClearEditingSearchField: NSSearchField {
    var onFocusChange: ((Bool) -> Void)?

    override class var cellClass: AnyClass? {
        get { ClearEditingSearchFieldCell.self }
        set {}
    }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { onFocusChange?(true) }
        return became
    }

    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        onFocusChange?(false)
    }
}

final class ClearEditingSearchFieldCell: NSSearchFieldCell {
    override func setUpFieldEditorAttributes(_ textObj: NSText) -> NSText {
        let editor = super.setUpFieldEditorAttributes(textObj)
        editor.drawsBackground = false
        return editor
    }
}
