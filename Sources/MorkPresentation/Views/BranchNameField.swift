import AppKit
import SwiftUI

struct BranchNameField: NSViewRepresentable {
    @Binding var text: String
    let onMove: (Int) -> Bool
    let onSubmit: () -> Void
    let onDismiss: () -> Bool
    let onFocus: (Bool) -> Void
    var identifier = "branchSheet.name"

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.placeholderAttributedString = NSAttributedString(string: "Branch name", attributes: [
            .font: NSFont.systemFont(ofSize: Metrics.FontSize.title),
            .foregroundColor: Palette.Text.tertiary.nsColor
        ])
        field.placeholderString = "Branch name"
        field.font = .systemFont(ofSize: Metrics.FontSize.title)
        field.textColor = Palette.Text.primary.nsColor
        field.setAccessibilityIdentifier(identifier)
        field.delegate = context.coordinator
        DispatchQueue.main.async { field.window?.makeFirstResponder(field) }
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
    }

    @MainActor final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: BranchNameField
        init(_ parent: BranchNameField) { self.parent = parent }

        func controlTextDidBeginEditing(_ notification: Notification) { parent.onFocus(true) }
        func controlTextDidEndEditing(_ notification: Notification) { parent.onFocus(false) }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            let normalized = BranchNameInput.normalized(field.stringValue)
            if normalized != field.stringValue {
                let selection = field.currentEditor()?.selectedRange
                field.stringValue = normalized
                if let selection { field.currentEditor()?.selectedRange = selection }
            }
            parent.text = normalized
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.moveDown(_:)): return parent.onMove(1)
            case #selector(NSResponder.moveUp(_:)): return parent.onMove(-1)
            case #selector(NSResponder.insertNewline(_:)):
                parent.onSubmit()
                return true
            case #selector(NSResponder.cancelOperation(_:)): return parent.onDismiss()
            default: return false
            }
        }
    }
}
