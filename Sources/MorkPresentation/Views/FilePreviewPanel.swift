import AppKit
import SwiftUI

struct FilePreviewHost: View {
    let viewModel: RepositoryViewModel
    @Environment(\.diffMetrics) private var metrics

    var body: some View {
        FilePreviewPresenter(viewModel: viewModel, path: viewModel.previewedFilePath, metrics: metrics)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
    }
}

private struct FilePreviewPresenter: NSViewRepresentable {
    let viewModel: RepositoryViewModel
    let path: String?
    let metrics: DiffMetrics

    func makeCoordinator() -> FilePreviewPanel {
        FilePreviewPanel()
    }

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.update(viewModel: viewModel, path: path, metrics: metrics, parent: view.window)
    }

    static func dismantleNSView(_ view: NSView, coordinator: FilePreviewPanel) {
        coordinator.close()
    }
}

@MainActor
final class FilePreviewPanel: NSObject, NSWindowDelegate {
    private var window: FilePreviewWindow?
    private weak var viewModel: RepositoryViewModel?

    func update(viewModel next: RepositoryViewModel, path: String?, metrics: DiffMetrics, parent: NSWindow?) {
        if viewModel !== next { close() }
        viewModel = next
        guard let path, let parent else {
            close()
            return
        }
        let window = window ?? open(on: parent, metrics: metrics)
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

    private func open(on parent: NSWindow, metrics: DiffMetrics) -> FilePreviewWindow {
        let share = Metrics.FilePreview.windowShare
        let width = max(Metrics.FilePreview.minimumWidth, parent.frame.width * share)
        let height = max(Metrics.FilePreview.minimumHeight, parent.frame.height * share)
        let frame = NSRect(x: parent.frame.midX - width / 2, y: parent.frame.midY - height / 2, width: width, height: height)
        let window = FilePreviewWindow.make(frame: frame)
        window.becomesKeyOnlyIfNeeded = true
        window.hidesOnDeactivate = true
        window.minSize = NSSize(width: Metrics.FilePreview.minimumWidth, height: Metrics.FilePreview.minimumHeight)
        window.setAccessibilityIdentifier("filePreview")
        window.delegate = self
        window.onClose = { [weak self] in self?.viewModel?.closeFilePreview() }
        if let viewModel {
            window.show(PreviewChrome(close: { [weak window] in window?.onClose?() }) {
                Text(viewModel.previewedFilePath ?? "")
                    .font(Metrics.Font.title)
                    .foregroundStyle(Palette.Text.secondary.color)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .accessibilityIdentifier("filePreview.path")
            } trailing: {
                EmptyView()
            } content: {
                FilePreviewContent(viewModel: viewModel, metrics: metrics)
            })
        }
        window.setFrame(frame, display: false)
        parent.addChildWindow(window, ordered: .above)
        window.orderFront(nil)
        self.window = window
        return window
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        viewModel?.closeFilePreview()
    }
}

final class FilePreviewWindow: NSPanel {
    var onClose: (() -> Void)?

    override var canBecomeKey: Bool { true }

    static func make(frame: NSRect) -> FilePreviewWindow {
        let window = FilePreviewWindow(contentRect: frame, styleMask: [.borderless, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        return window
    }

    func show<Content: View>(_ content: Content) {
        contentView = NSHostingView(rootView: content)
        setFrame(frame, display: false)
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty, event.charactersIgnoringModifiers == " " {
            onClose?()
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        onClose?()
    }
}

struct PreviewChrome<Title: View, Trailing: View, Content: View>: View {
    let close: () -> Void
    @ViewBuilder let title: Title
    @ViewBuilder let trailing: Trailing
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Metrics.Spacing.s) {
                Button(action: close) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: Metrics.Icon.regular))
                        .foregroundStyle(Palette.Text.secondary.color)
                        .frame(width: Metrics.HitTarget.inline, height: Metrics.HitTarget.inline)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Close (Space)")
                .accessibilityLabel("Close")
                .accessibilityIdentifier("preview.close")
                title
                Spacer(minLength: Metrics.Spacing.s)
                trailing
            }
            .padding(.horizontal, Metrics.Spacing.s)
            .frame(height: Metrics.Panel.header)
            content
        }
        .background(Palette.Surface.window.color)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.popover))
        .overlay(RoundedRectangle(cornerRadius: Metrics.Radius.popover).strokeBorder(Palette.Surface.borderStrong.color))
    }
}

private struct FilePreviewContent: View {
    let viewModel: RepositoryViewModel
    let metrics: DiffMetrics

    var body: some View {
        Group {
            switch viewModel.detail {
            case .empty, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .failed(message):
                EmptyStateView("Could Not Load", systemImage: "exclamationmark.triangle", message: message)
            case let .loaded(text):
                if let document = viewModel.diffDocument, !text.isEmpty, document.lines.contains(where: { $0.kind != .meta }) {
                    SplitDiffTableView(document: document, metrics: metrics)
                } else {
                    EmptyStateView("No Text Changes", systemImage: "doc.text")
                        .accessibilityIdentifier("filePreview.empty")
                }
            }
        }
        .background(Palette.Surface.window.color)
    }
}
