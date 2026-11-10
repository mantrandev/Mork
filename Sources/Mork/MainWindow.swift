import AppKit
import MorkPresentation
import MorkTerminal
import SwiftUI

struct MainWindow: View {
    @MainActor private static var isPrimaryShown = false

    let primary: AppViewModel
    let options: LaunchOptions
    @State private var model: AppViewModel?

    var body: some View {
        ZStack {
            if let model {
                RootView(app: model) { url, focusRequest in
                    AnyView(RepositoryTerminal(directory: url, focusRequest: focusRequest))
                }
                .environment(\.sidebarExpandsAllSections, options.expandsSidebarSections)
            } else {
                Color(nsColor: .windowBackgroundColor)
            }
        }
        .frame(minWidth: 900, minHeight: 680)
        .task { await start() }
        .onReceive(NotificationCenter.default.publisher(for: MemoryPressureMonitor.didRaise)) { _ in
            model?.releaseMemory()
        }
        .onDisappear {
            if model === primary { Self.isPrimaryShown = false }
        }
    }

    private func start() async {
        guard model == nil else { return }
        guard !Self.isPrimaryShown else {
            let window = primary.makeWindow()
            model = window
            await window.openPendingWindowTabs()
            return
        }
        Self.isPrimaryShown = true
        model = primary
        if let size = options.windowSize, let window = NSApp.windows.first(where: { $0.isVisible && $0.styleMask.contains(.titled) }) {
            window.setContentSize(size)
            if let screen = NSScreen.screens.first, window.screen != screen {
                let frame = window.frame
                let origin = NSPoint(x: screen.visibleFrame.midX - frame.width / 2, y: screen.visibleFrame.midY - frame.height / 2)
                window.setFrameOrigin(origin)
            }
        }
        Task { await primary.repositoryManager.rescan() }
        await primary.restoreTabs()
        if let url = options.repositoryURL {
            await primary.open(url)
        }
        ExternalOpenQueue.shared.attach { [primary] urls in
            Task { @MainActor in
                for url in urls { await primary.open(url) }
            }
        }
    }
}
