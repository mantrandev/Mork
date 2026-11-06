import AppKit
import MorkPresentation
import MorkTerminal
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        ExternalOpenQueue.shared.receive(urls)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        ShellSession.terminateAll()
    }
}

@main
struct MorkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let options = LaunchOptions(arguments: CommandLine.arguments)
    @State private var app = AppContainer.makeAppViewModel(
        defaults: AppContainer.makeDefaults(for: LaunchOptions(arguments: CommandLine.arguments)),
        panels: LaunchFilePanels(options: LaunchOptions(arguments: CommandLine.arguments)),
        folderPanel: LaunchFolderPanel(options: LaunchOptions(arguments: CommandLine.arguments)),
        accountServices: AccountServices.make(
            defaults: AppContainer.makeDefaults(for: LaunchOptions(arguments: CommandLine.arguments)),
            options: LaunchOptions(arguments: CommandLine.arguments)
        )
    )

    var body: some Scene {
        WindowGroup("Mork", id: "main") {
            MainWindow(primary: app, options: options)
        }
        .handlesExternalEvents(matching: [])
        .defaultSize(width: 1280, height: 860)
        .windowStyle(.hiddenTitleBar)
        .commands {
            RepositoryCommands()
            HistoryCommands()
            AppCommands(app: app)
        }
        Settings {
            SettingsView(viewModel: app.settings, accounts: app.accounts, sshKeys: app.sshKeys)
        }
    }
}
