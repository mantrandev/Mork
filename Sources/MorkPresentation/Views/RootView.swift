import AppKit
import SwiftUI

public struct RootView: View {
    @Bindable private var app: AppViewModel
    private let makeTerminal: TerminalFactory

    public init(app: AppViewModel, makeTerminal: @escaping TerminalFactory = { _, _ in AnyView(Text("Terminal unavailable")) }) {
        self.app = app
        self.makeTerminal = makeTerminal
    }

    public var body: some View {
        ZStack {
            if let repository = app.retainedRepository {
                let isBehindManager = app.repository == nil
                RepositoryView(viewModel: repository, console: app.console, app: app, makeTerminal: makeTerminal, isBehindManager: isBehindManager)
                    .opacity(isBehindManager ? 0 : 1)
                    .allowsHitTesting(!isBehindManager)
                    .accessibilityHidden(isBehindManager)
            }
            if app.repository == nil {
                RepositoryManagerScreen(app: app, manager: app.repositoryManager, onOpen: open, onInitialize: initialize)
                    .background(Palette.Surface.window.color)
            }
        }
        .overlay {
            if let quickLaunch = app.quickLaunch {
                QuickLaunchPalette(app: app, quickLaunch: quickLaunch, onChooseFolder: chooseFolder)
            }
        }
        .folderDropTarget(app)
        .errorAlert($app.errorMessage)
        .sheet(isPresented: $app.isCloneSheetPresented) { CloneSheet(app: app) }
        .sheet(isPresented: $app.isWorkspaceSheetPresented) { WorkspacesSheet(app: app) }
        .sheet(item: $app.renamingTab) { RenameTabSheet(app: app, tab: $0) }
        .sheet(item: $app.rebaseSession) { InteractiveRebaseSheet(session: $0) }
        .environment(app.authorAvatars)
        .focusedSceneValue(\.appModel, app)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in app.setAppActive(false) }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in app.setAppActive(true) }
    }

    private func open() {
        Task { await app.openChosenFolder() }
    }

    private func chooseFolder(for command: QuickLaunchCommand) {
        if command == .initializeRepository { initialize() } else { open() }
    }

    private func initialize() {
        Task { await app.initializeChosenFolder() }
    }
}
