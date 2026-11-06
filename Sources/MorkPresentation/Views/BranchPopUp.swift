import AppKit
import SwiftUI

struct BranchPopUp: NSViewRepresentable {
    struct Item: Equatable {
        let title: String
        let tag: String
        var systemImage: String? = nil
    }

    let items: [Item]
    @Binding var selection: String
    let identifier: String

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.font = .systemFont(ofSize: Metrics.FontSize.title)
        button.target = context.coordinator
        button.action = #selector(Coordinator.choose(_:))
        button.setAccessibilityIdentifier(identifier)
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        let coordinator = context.coordinator
        coordinator.selection = $selection
        coordinator.button = button
        if coordinator.items != items {
            coordinator.items = items
            coordinator.isPopulated = false
            let menu = NSMenu()
            menu.delegate = coordinator
            button.menu = menu
        }
        coordinator.showSelection()
        let isEnabled = context.environment.isEnabled && !items.isEmpty
        if button.isEnabled != isEnabled { button.isEnabled = isEnabled }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSPopUpButton, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? Metrics.Control.pickerWidth, height: Metrics.Control.regular)
    }

    @MainActor
    final class Coordinator: NSObject, NSMenuDelegate {
        var selection: Binding<String>
        var items: [Item] = []
        var isPopulated = false
        weak var button: NSPopUpButton?
        private var images: [String: NSImage] = [:]

        init(selection: Binding<String>) {
            self.selection = selection
        }

        func showSelection() {
            guard let button, let menu = button.menu else { return }
            let tag = selection.wrappedValue
            if isPopulated {
                let index = items.firstIndex { $0.tag == tag } ?? -1
                if button.indexOfSelectedItem != index { button.selectItem(at: index) }
                return
            }
            guard let item = items.first(where: { $0.tag == tag }) else {
                menu.removeAllItems()
                return
            }
            if menu.items.count == 1, menu.items[0].representedObject as? String == tag { return }
            menu.removeAllItems()
            menu.addItem(entry(for: item))
            button.selectItem(at: 0)
        }

        func menuNeedsUpdate(_ menu: NSMenu) {
            guard !isPopulated else { return }
            isPopulated = true
            menu.removeAllItems()
            for item in items { menu.addItem(entry(for: item)) }
            showSelection()
        }

        private func entry(for item: Item) -> NSMenuItem {
            let entry = NSMenuItem(title: item.title, action: nil, keyEquivalent: "")
            entry.representedObject = item.tag
            if let name = item.systemImage {
                if images[name] == nil { images[name] = NSImage(systemSymbolName: name, accessibilityDescription: nil) }
                entry.image = images[name]
            }
            return entry
        }

        @objc func choose(_ sender: NSPopUpButton) {
            guard let tag = sender.selectedItem?.representedObject as? String, tag != selection.wrappedValue else { return }
            selection.wrappedValue = tag
        }
    }
}
