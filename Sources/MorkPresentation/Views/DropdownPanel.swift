import AppKit
import SwiftUI

@MainActor
final class DropdownPanel {
    fileprivate weak var anchorView: NSView?
    private var window: DropdownWindow?
    private var host: NSView?
    private var top: CGFloat = 0
    private var measuredHeight: CGFloat = 0
    private var closedAt = Date.distantPast
    private var observers: [NSObjectProtocol] = []

    var isShown: Bool { window != nil }

    func toggle<Content: View>(identifier: String, minimumWidth: CGFloat, matchesAnchorWidth: Bool, @ViewBuilder content: (_ maximumHeight: CGFloat) -> Content) {
        if window != nil {
            close()
            return
        }
        guard Date().timeIntervalSince(closedAt) > Metrics.Dropdown.reopenDelay, let anchorView, let parent = anchorView.window else { return }
        let anchor = parent.convertToScreen(anchorView.convert(anchorView.bounds, to: nil))
        let width = max(minimumWidth, matchesAnchorWidth ? anchor.width : 0)
        let bounds = (parent.screen ?? NSScreen.main)?.visibleFrame ?? parent.frame
        let limit = min(parent.frame.maxX, bounds.maxX) - Metrics.Spacing.s
        var x = matchesAnchorWidth ? anchor.midX - width / 2 : anchor.minX
        x = max(min(x, limit - width), max(parent.frame.minX, bounds.minX) + Metrics.Spacing.s)
        top = anchor.minY - Metrics.Dropdown.gap
        let maximumHeight = min(parent.frame.height * Metrics.Dropdown.maximumShare, top - bounds.minY - Metrics.Spacing.s)

        let root = content(maximumHeight)
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }, action: { [weak self] in self?.resize(to: $0) })
            .frame(width: width)
            .frame(maxHeight: .infinity, alignment: .top)
        let hosting = NSHostingView(rootView: root)
        hosting.sizingOptions = []
        measuredHeight = 0
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: max(maximumHeight, Metrics.Dropdown.row))
        hosting.layoutSubtreeIfNeeded()
        let height = max(measuredHeight, Metrics.Dropdown.row)

        let effect = DropdownSurfaceView()
        effect.frame = NSRect(x: 0, y: 0, width: width, height: height)
        hosting.frame = effect.bounds
        hosting.autoresizingMask = [.width, .height]
        effect.addSubview(hosting)

        let window = DropdownWindow(contentRect: NSRect(x: x, y: top - height, width: width, height: height), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.contentView = effect
        window.setAccessibilityIdentifier(identifier)
        window.onCancel = { [weak self] in self?.close() }
        window.alphaValue = 0
        parent.addChildWindow(window, ordered: .above)
        window.makeKeyAndOrderFront(nil)
        window.invalidateShadow()
        self.window = window
        self.host = hosting
        observers = [
            NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.close(restoresFocus: false) }
            },
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: parent, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.close(restoresFocus: false) }
            }
        ]
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Metrics.Dropdown.fade
            window.animator().alphaValue = 1
        }
    }

    func show(identifier: String, minimumWidth: CGFloat = Metrics.Dropdown.menuMinimumWidth, rowHeight: CGFloat = Metrics.Dropdown.row, _ entries: [MenuEntry]) {
        toggle(identifier: "\(identifier).window", minimumWidth: minimumWidth, matchesAnchorWidth: false) { _ in
            DropdownMenu(entries: entries, identifier: identifier, close: { [weak self] in self?.close() }, rowHeight: rowHeight)
        }
    }

    func close() {
        close(restoresFocus: true)
    }

    private func close(restoresFocus: Bool) {
        guard let window else { return }
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        self.window = nil
        host = nil
        closedAt = Date()
        let parent = window.parent
        if restoresFocus { parent?.makeKey() }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Metrics.Dropdown.fade * 0.6
            window.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated {
                parent?.removeChildWindow(window)
                window.orderOut(nil)
            }
        }
    }

    private func resize(to height: CGFloat) {
        measuredHeight = height
        guard let window, height > 0, abs(window.frame.height - height) > 0.5 else { return }
        window.setFrame(NSRect(x: window.frame.minX, y: top - height, width: window.frame.width, height: height), display: true)
        window.invalidateShadow()
    }
}

final class DropdownSurfaceView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = Metrics.Dropdown.radius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        layer?.borderWidth = Metrics.Line.hairline
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = Palette.Surface.raised.nsColor.cgColor
            layer?.borderColor = Palette.Surface.border.nsColor.cgColor
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

struct PopoverShadow: ViewModifier {
    static let ink = Color(nsColor: Palette.Text.primary.light.nsColor)

    func body(content: Content) -> some View {
        content
            .shadow(color: Self.ink.opacity(Metrics.Shadow.ambientOpacity), radius: Metrics.Shadow.ambientRadius, y: Metrics.Shadow.ambientY)
            .shadow(color: Self.ink.opacity(Metrics.Shadow.keyOpacity), radius: Metrics.Shadow.keyRadius, y: Metrics.Shadow.keyY)
    }
}

private final class DropdownWindow: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

struct DropdownAnchorView: NSViewRepresentable {
    let panel: DropdownPanel

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        panel.anchorView = view
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        panel.anchorView = view
    }
}

struct DropdownMenu: View {
    let entries: [MenuEntry]
    let identifier: String
    let close: () -> Void
    var rowHeight = Metrics.Dropdown.row
    @State private var selected: Int?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(entries.indices, id: \.self) { index in
                let entry = entries[index]
                if entry.isSeparator {
                    Hairline()
                        .padding(.vertical, Metrics.Spacing.xs)
                        .padding(.horizontal, Metrics.Spacing.m)
                } else {
                    DropdownMenuRow(entry: entry, isSelected: selected == index, height: rowHeight)
                        .onHover { if $0, entry.isEnabled { selected = index } }
                        .onTapGesture { run(entry) }
                        .accessibilityAction { run(entry) }
                }
            }
        }
        .padding(Metrics.Spacing.xs)
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress(.downArrow) {
            move(by: 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            move(by: -1)
            return .handled
        }
        .onKeyPress(.return) {
            if let selected { run(entries[selected]) }
            return .handled
        }
        .onKeyPress(.escape) {
            close()
            return .handled
        }
        .task {
            for _ in 0..<20 where !isFocused {
                isFocused = true
                try? await Task.sleep(for: .milliseconds(25))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private func move(by offset: Int) {
        let enabled = entries.indices.filter { !entries[$0].isSeparator && entries[$0].isEnabled }
        guard !enabled.isEmpty else { return }
        guard let selected, let position = enabled.firstIndex(of: selected) else {
            self.selected = offset > 0 ? enabled.first : enabled.last
            return
        }
        self.selected = enabled[min(max(position + offset, 0), enabled.count - 1)]
    }

    private func run(_ entry: MenuEntry) {
        guard entry.isEnabled, !entry.isSeparator else { return }
        close()
        entry.action()
    }
}

struct SelectionHighlight: View {
    let isSelected: Bool
    var isHovered = false

    var body: some View {
        RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous)
            .fill(Palette.Text.primary.color.opacity(Self.opacity(isSelected: isSelected, isHovered: isHovered)))
    }

    static func opacity(isSelected: Bool, isHovered: Bool) -> Double {
        isSelected ? Palette.Ink.selection : isHovered ? Palette.Ink.hover : 0
    }
}

private struct DropdownMenuRow: View {
    let entry: MenuEntry
    let isSelected: Bool
    let height: CGFloat

    var body: some View {
        HStack(spacing: Metrics.Spacing.s) {
            Image(systemName: "checkmark")
                .font(Metrics.Font.caption.weight(.bold))
                .foregroundStyle(Palette.Accent.text.color)
                .opacity(entry.isChecked ? 1 : 0)
                .frame(width: Metrics.Dropdown.checkColumn)
            if let dotColor = entry.dotColor {
                Circle()
                    .fill(dotColor)
                    .frame(width: Metrics.Dropdown.dot, height: Metrics.Dropdown.dot)
            } else {
                Group {
                    if let image = entry.image {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                    } else if let systemImage = entry.systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: Metrics.Icon.regular))
                            .foregroundStyle(Palette.Text.secondary.color)
                    }
                }
                .frame(width: Metrics.Icon.column, height: Metrics.Icon.column)
            }
            Text(entry.title)
                .font(Metrics.Font.title)
                .lineLimit(1)
                .frame(width: entry.detail == nil ? nil : Metrics.Dropdown.titleColumn, alignment: .leading)
            if let detail = entry.detail {
                Text(detail)
                    .font(Metrics.Font.title)
                    .lineLimit(1)
            }
            Spacer(minLength: Metrics.Spacing.s)
            if !entry.keyEquivalent.isEmpty {
                Text(entry.keyEquivalent)
                    .font(Metrics.Font.body)
                    .foregroundStyle(Palette.Text.secondary.color)
            }
        }
        .foregroundStyle(entry.isEnabled ? Palette.Text.primary.color : Palette.Text.tertiary.color)
        .padding(.horizontal, Metrics.Spacing.xs)
        .frame(height: height)
        .background(SelectionHighlight(isSelected: isSelected && entry.isEnabled))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(entry.isChecked ? "checked" : "")
        .accessibilityIdentifier(entry.identifier ?? entry.title)
    }
}
