import AppKit
import SwiftUI

private struct LinkCursor: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.pointerStyle(.link)
        } else {
            content.onHover { inside in
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
    }
}

extension View {
    func linkCursor() -> some View {
        modifier(LinkCursor())
    }
}
