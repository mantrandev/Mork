import AppKit
import SwiftUI

struct ConflictWindowHost: View {
    let viewModel: RepositoryViewModel

    var body: some View {
        ConflictWindowPresenter(viewModel: viewModel, path: viewModel.conflictWindowPath)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
    }
}

private struct ConflictWindowPresenter: NSViewRepresentable {
    let viewModel: RepositoryViewModel
    let path: String?

    func makeCoordinator() -> ConflictWindowPanel {
        ConflictWindowPanel()
    }

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.update(viewModel: viewModel, path: path, parent: view.window)
    }

    static func dismantleNSView(_ view: NSView, coordinator: ConflictWindowPanel) {
        coordinator.close()
    }
}

@MainActor
final class ConflictWindowPanel: NSObject, NSWindowDelegate {
    private(set) var window: ConflictWindow?
    private weak var viewModel: RepositoryViewModel?

    static func frame(centeredOn base: NSRect) -> NSRect {
        let share = Metrics.Conflict.windowShare
        let width = max(Metrics.Conflict.windowMinimumWidth, base.width * share)
        let height = max(Metrics.Conflict.windowMinimumHeight, base.height * share)
        return NSRect(x: base.midX - width / 2, y: base.midY - height / 2, width: width, height: height)
    }

    func update(viewModel next: RepositoryViewModel, path: String?, parent: NSWindow?) {
        if viewModel !== next { close() }
        viewModel = next
        guard let path, let parent else {
            close()
            return
        }
        let window = window ?? open(on: parent, viewModel: next)
        window.title = path
        window.representedURL = next.url.appendingPathComponent(path)
    }

    func close() {
        guard let window else { return }
        self.window = nil
        window.delegate = nil
        window.parent?.removeChildWindow(window)
        window.orderOut(nil)
        window.close()
    }

    private func open(on parent: NSWindow, viewModel: RepositoryViewModel) -> ConflictWindow {
        let frame = Self.frame(centeredOn: parent.frame)
        let window = ConflictWindow.make(frame: frame)
        window.hidesOnDeactivate = true
        window.setAccessibilityIdentifier("conflictWindow")
        window.delegate = self
        window.onClose = { [weak viewModel] in viewModel?.closeConflictWindow() }
        window.onNext = { [weak viewModel] in viewModel?.showNextConflict() }
        window.onPrevious = { [weak viewModel] in viewModel?.showPreviousConflict() }
        window.onSave = { [weak viewModel] in
            guard let resolver = viewModel?.conflictWindowResolver else { return }
            Task { await resolver.save() }
        }
        window.show(ConflictWindowView(viewModel: viewModel, close: { [weak window] in window?.onClose?() }))
        window.setFrame(frame, display: false)
        parent.addChildWindow(window, ordered: .above)
        window.makeKeyAndOrderFront(nil)
        self.window = window
        return window
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        viewModel?.closeConflictWindow()
    }
}

final class ConflictWindow: NSPanel {
    var onClose: (() -> Void)?
    var onNext: (() -> Void)?
    var onPrevious: (() -> Void)?
    var onSave: (() -> Void)?

    override var canBecomeKey: Bool { true }

    static func make(frame: NSRect) -> ConflictWindow {
        let window = ConflictWindow(contentRect: frame, styleMask: [.borderless, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.minSize = NSSize(width: Metrics.Conflict.windowMinimumWidth, height: Metrics.Conflict.windowMinimumHeight)
        return window
    }

    func show<Content: View>(_ content: Content) {
        let host = NSHostingView(rootView: content)
        host.sizingOptions = []
        contentView = host
        setFrame(frame, display: false)
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty, [" ", "\u{1b}"].contains(event.charactersIgnoringModifiers) {
            onClose?()
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        onClose?()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown, event.modifierFlags.intersection([.command, .shift, .option, .control]) == .command else {
            return super.performKeyEquivalent(with: event)
        }
        switch event.charactersIgnoringModifiers {
        case "]": onNext?()
        case "[": onPrevious?()
        case "s": onSave?()
        default: return super.performKeyEquivalent(with: event)
        }
        return true
    }
}

struct ConflictWindowView: View {
    let viewModel: RepositoryViewModel
    let close: () -> Void

    var body: some View {
        PreviewChrome(close: close) {
            ConflictWindowTitle(viewModel: viewModel)
        } trailing: {
            ConflictWindowNavigation(viewModel: viewModel)
        } content: {
            VStack(spacing: 0) {
                Hairline()
                ConflictWindowContent(viewModel: viewModel)
            }
        }
    }
}

private struct ConflictWindowTitle: View {
    let viewModel: RepositoryViewModel

    var body: some View {
        Text(viewModel.conflictWindowPath ?? "")
            .font(Metrics.Font.title)
            .foregroundStyle(Palette.Text.secondary.color)
            .lineLimit(1)
            .truncationMode(.head)
            .accessibilityIdentifier("conflictWindow.path")
    }
}

private struct ConflictWindowNavigation: View {
    let viewModel: RepositoryViewModel

    var body: some View {
        let position = viewModel.conflictWindowPosition
        HStack(spacing: Metrics.Spacing.xs) {
            if let position {
                Text("\(position.index + 1) of \(position.count)")
                    .font(Metrics.Font.caption)
                    .monospacedDigit()
                    .foregroundStyle(Palette.Text.secondary.color)
                    .accessibilityIdentifier("conflictWindow.position")
            }
            ConflictStepButton(title: "Previous", systemImage: "chevron.left", help: "Previous conflicted file (⌘[)", identifier: "conflictWindow.previous") {
                viewModel.showPreviousConflict()
            }
            .disabled((position?.index ?? 0) <= 0)
            ConflictStepButton(title: "Next", systemImage: "chevron.right", help: "Next conflicted file (⌘])", identifier: "conflictWindow.next") {
                viewModel.showNextConflict()
            }
            .disabled(position.map { $0.index >= $0.count - 1 } ?? true)
        }
    }
}

private struct ConflictStepButton: View {
    let title: String
    let systemImage: String
    let help: String
    let identifier: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: Metrics.Icon.small, weight: .medium))
                .foregroundStyle(isEnabled ? Palette.Text.secondary.color : Palette.Text.tertiary.color)
                .frame(width: Metrics.HitTarget.inline, height: Metrics.HitTarget.inline)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }
}

private struct ConflictWindowContent: View {
    let viewModel: RepositoryViewModel

    var body: some View {
        Group {
            if let resolver = viewModel.conflictWindowResolver {
                ConflictResolverView(resolver: resolver, repository: viewModel, isInWindow: true)
                    .id(ObjectIdentifier(resolver))
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.Surface.window.color)
    }
}
