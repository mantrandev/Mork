import AppKit
import SwiftUI

public typealias TerminalFactory = @MainActor (URL, Int) -> AnyView

struct AppFocusedValueKey: FocusedValueKey {
    typealias Value = AppViewModel
}

extension FocusedValues {
    var appModel: AppViewModel? {
        get { self[AppFocusedValueKey.self] }
        set { self[AppFocusedValueKey.self] = newValue }
    }
}

public struct AppCommands: Commands {
    private let app: AppViewModel
    @FocusedValue(\.appModel) private var focusedApp
    @Environment(\.openWindow) private var openWindow

    private var window: AppViewModel { focusedApp ?? app }

    public init(app: AppViewModel) {
        self.app = app
    }

    public var body: some Commands {
        CommandGroup(after: .appSettings) {
            SettingsTabButton(title: "Accounts…", tab: .accounts, app: app)
            SettingsTabButton(title: "Configure SSH Keys…", tab: .ssh, app: app)
        }
        CommandGroup(replacing: .newItem) {
            Button("New Window") { openWindow(id: "main") }
                .keyboardShortcut("n")
            Button("New Tab") { window.openManagerTab() }
                .keyboardShortcut("t")
            Button("Restore Closed Tab") { Task { await window.restoreClosedTab() } }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                .disabled(window.closedTabs.isEmpty)
            Divider()
            Button("Create New Local Repository…") { Task { await window.initializeChosenFolder() } }
            Button("Clone…") { window.showCloneSheet() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Divider()
            Button("Open…") { Task { await window.openChosenFolder() } }
                .keyboardShortcut("o")
            Menu("Open Recent") {
                ForEach(app.recentRepositories, id: \.self) { url in
                    Button(RecentLocation.title(for: url)) { Task { await window.open(url) } }
                }
                Divider()
                Button("Clear Menu") { app.clearRecentRepositories() }
                    .disabled(app.recentRepositories.isEmpty)
            }
            Button("Quick Launch…") { window.toggleQuickLaunch() }
                .keyboardShortcut("p")
        }
        CommandGroup(replacing: .saveItem) {
            Button("Close Window") { NSApp.keyWindow?.performClose(nil) }
                .keyboardShortcut("w", modifiers: [.command, .shift])
            Button("Close Tab") { closeTabOrWindow() }
                .keyboardShortcut("w")
        }
        CommandGroup(before: .windowList) {
            Button("Show Next Tab") { window.selectNextTab() }
                .keyboardShortcut(.tab, modifiers: .control)
                .disabled(!window.showsTabBar)
            Button("Show Previous Tab") { window.selectPreviousTab() }
                .keyboardShortcut(.tab, modifiers: [.control, .shift])
                .disabled(!window.showsTabBar)
            ForEach(Array(window.tabs.prefix(8).enumerated()), id: \.element.url) { index, tab in
                Button(tab.name) { window.selectTab(number: index + 1) }
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))))
            }
            Button("Show Last Tab") { window.selectTab(number: 9) }
                .keyboardShortcut("9")
                .disabled(window.tabs.isEmpty)
            Divider()
            WorkspacesMenu(app: app)
            Divider()
        }
        CommandGroup(after: .toolbar) {
            Button(window.showsBottomPanel ? "Hide Git Console" : "Show Git Console") { window.toggleBottomPanel() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
        }
        CommandGroup(replacing: .help) {
            ForEach(HelpLink.allCases, id: \.self) { link in
                if link == .repository { Divider() }
                Button(link.title) { NSWorkspace.shared.open(link.url) }
            }
        }
    }

    private func closeTabOrWindow() {
        if let focusedApp, focusedApp.repository != nil {
            focusedApp.close()
        } else if let focusedApp, focusedApp.hasManagerTab {
            focusedApp.closeManagerTab()
        } else {
            NSApp.keyWindow?.performClose(nil)
        }
    }
}

private struct SettingsTabButton: View {
    let title: String
    let tab: SettingsViewModel.Tab
    let app: AppViewModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button(title) {
            app.showSettings(tab)
            openSettings()
        }
    }
}

enum RecentLocation {
    static func title(for url: URL) -> String {
        (url.path as NSString).abbreviatingWithTildeInPath
    }
}

enum HelpLink: CaseIterable {
    case gitReference
    case proGitBook
    case repository
    case issues

    var title: String {
        switch self {
        case .gitReference: "Git Command Reference"
        case .proGitBook: "Pro Git Book"
        case .repository: "Mork on GitHub"
        case .issues: "Report an Issue"
        }
    }

    var url: URL {
        switch self {
        case .gitReference: URL(string: "https://git-scm.com/docs")!
        case .proGitBook: URL(string: "https://git-scm.com/book")!
        case .repository: URL(string: "https://github.com/mantrandev/Mork")!
        case .issues: URL(string: "https://github.com/mantrandev/Mork/issues")!
        }
    }
}
