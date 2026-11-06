import AppKit
import MorkDomain
import SwiftUI

struct CommitPreviewHost: View {
    let viewModel: RepositoryViewModel
    @Environment(\.diffMetrics) private var metrics

    var body: some View {
        CommitPreviewPresenter(viewModel: viewModel, commit: viewModel.previewedCommit, metrics: metrics)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
    }
}

private struct CommitPreviewPresenter: NSViewRepresentable {
    let viewModel: RepositoryViewModel
    let commit: Commit?
    let metrics: DiffMetrics

    func makeCoordinator() -> CommitPreviewPanel {
        CommitPreviewPanel()
    }

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.update(viewModel: viewModel, commit: commit, metrics: metrics, parent: view.window)
    }

    static func dismantleNSView(_ view: NSView, coordinator: CommitPreviewPanel) {
        coordinator.close()
    }
}

@MainActor
final class CommitPreviewPanel: NSObject, NSWindowDelegate {
    private(set) var window: FilePreviewWindow?
    private weak var viewModel: RepositoryViewModel?
    private var metrics = DiffMetrics.standard

    func update(viewModel next: RepositoryViewModel, commit: Commit?, metrics: DiffMetrics, parent: NSWindow?) {
        if viewModel !== next { close() }
        viewModel = next
        self.metrics = metrics
        guard let commit, let parent else {
            close()
            return
        }
        let window = window ?? open(on: parent, viewModel: next)
        window.title = commit.subject
    }

    func close() {
        guard let window else { return }
        self.window = nil
        window.delegate = nil
        window.parent?.removeChildWindow(window)
        window.orderOut(nil)
        window.close()
    }

    private func open(on parent: NSWindow, viewModel: RepositoryViewModel) -> FilePreviewWindow {
        let window = FilePreviewWindow.make(frame: CommitWindows.frame(centeredOn: parent))
        window.becomesKeyOnlyIfNeeded = true
        window.hidesOnDeactivate = true
        window.minSize = NSSize(width: Metrics.FilePreview.minimumWidth, height: Metrics.FilePreview.minimumHeight)
        window.setAccessibilityIdentifier("commitPreview")
        window.delegate = self
        window.onClose = { [weak viewModel] in viewModel?.closeCommitPreview() }
        window.show(PreviewChrome(close: { [weak window] in window?.onClose?() }) {
            EmptyView()
        } trailing: {
            OpenCommitWindowButton { [weak self] in self?.openSeparately() }
        } content: {
            CommitPreviewContent(viewModel: viewModel)
                .environment(\.diffMetrics, metrics)
        })
        parent.addChildWindow(window, ordered: .above)
        window.orderFront(nil)
        self.window = window
        return window
    }

    func openSeparately() {
        guard let viewModel, let detached = viewModel.detachCommitPreview() else { return }
        CommitWindows.shared.show(detached, metrics: metrics, near: window?.parent)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        viewModel?.closeCommitPreview()
    }
}

struct OpenCommitWindowButton: View {
    let action: () -> Void

    var body: some View {
        Button("Open in Separate Window", action: action)
            .buttonStyle(.mork(.secondary, size: .small))
            .accessibilityIdentifier("commitPreview.openWindow")
    }
}

private struct CommitPreviewContent: View {
    let viewModel: RepositoryViewModel

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.commitDetailsTab == .commit, let commit = viewModel.previewedCommit ?? viewModel.selectedCommit {
                CommitSummaryBar(commit: commit)
            }
            CommitInfoView(viewModel: viewModel)
        }
    }
}

@MainActor
final class CommitWindows: NSObject, NSWindowDelegate {
    static let shared = CommitWindows()

    private(set) var models: [ObjectIdentifier: RepositoryViewModel] = [:]
    private var windows: [ObjectIdentifier: NSWindow] = [:]

    static func frame(centeredOn parent: NSWindow?) -> NSRect {
        frame(centeredOn: parent?.frame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 860))
    }

    static func frame(centeredOn base: NSRect) -> NSRect {
        let share = Metrics.FilePreview.windowShare
        let width = max(Metrics.FilePreview.minimumWidth, base.width * share)
        let height = max(Metrics.FilePreview.minimumHeight, base.height * share)
        return NSRect(x: base.midX - width / 2, y: base.midY - height / 2, width: width, height: height)
    }

    @discardableResult
    func show(_ model: RepositoryViewModel, metrics: DiffMetrics, near parent: NSWindow?) -> NSWindow {
        let frame = Self.frame(centeredOn: parent)
        let window = NSWindow(contentRect: frame, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.title = model.selectedCommit?.subject ?? model.name
        window.minSize = NSSize(width: Metrics.FilePreview.minimumWidth, height: Metrics.FilePreview.minimumHeight)
        window.setAccessibilityIdentifier("commitWindow")
        window.contentView = NSHostingView(rootView: CommitPreviewContent(viewModel: model)
            .environment(\.diffMetrics, metrics)
            .background(Palette.Surface.window.color)
            .background(FilePreviewHost(viewModel: model)))
        window.setFrame(frame, display: false)
        window.delegate = self
        let id = ObjectIdentifier(window)
        models[id] = model
        windows[id] = window
        window.makeKeyAndOrderFront(nil)
        return window
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        let id = ObjectIdentifier(window)
        models[id] = nil
        windows[id] = nil
    }
}
