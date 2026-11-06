import AppKit
import SwiftUI

enum SettingsWindowLayout {
    static func preferredHeight(for tab: SettingsViewModel.Tab) -> CGFloat {
        switch tab {
        case .general: Metrics.Settings.generalHeight
        case .git: Metrics.Settings.gitHeight
        case .diff: Metrics.Settings.diffHeight
        case .learning: Metrics.Settings.learningHeight
        case .accounts: Metrics.Settings.accountsHeight
        case .ssh: Metrics.Settings.sshHeight
        case .integration: Metrics.Settings.integrationHeight
        case .customCommands: Metrics.Settings.customCommandsHeight
        }
    }

    static func height(for tab: SettingsViewModel.Tab, screenHeight: CGFloat?) -> CGFloat {
        let preferred = preferredHeight(for: tab)
        guard let screenHeight else { return preferred }
        return min(preferred, screenHeight - Metrics.Settings.windowChrome)
    }
}

extension View {
    func settingsPane(_ tab: SettingsViewModel.Tab) -> some View {
        frame(width: Metrics.Sheet.settingsWidth, height: SettingsWindowLayout.height(for: tab, screenHeight: NSScreen.main?.visibleFrame.height))
    }
}
