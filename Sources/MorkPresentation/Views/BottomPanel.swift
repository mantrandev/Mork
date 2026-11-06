import AppKit
import SwiftUI

struct BottomPanel: View {
    let app: AppViewModel
    let repositoryURL: URL
    var terminalURLs: [URL] = []
    let makeTerminal: TerminalFactory
    let onRun: (String) -> Void
    @State private var startedTerminals: Set<URL> = []

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Metrics.Spacing.xs) {
                ForEach(AppViewModel.BottomPanelTab.allCases) { tab in
                    tabButton(tab)
                }
                Spacer()
                if app.bottomPanelTab == .console {
                    ConsoleControls(console: app.console)
                }
                if app.bottomPanelTab == .terminal {
                    PanelIconButton(title: "Open in \(app.repository?.terminalAppName ?? "Terminal")", systemImage: "macwindow", identifier: "bottom.externalTerminal") {
                        Task { await app.repository?.openRepositoryInTerminalApp() }
                    }
                }
                PanelIconButton(title: "Hide Git Console", systemImage: "chevron.down", help: "Hide (⇧⌘C)", identifier: "bottom.hide") { app.toggleBottomPanel() }
            }
            .padding(.horizontal, Metrics.Spacing.m)
            .frame(height: Metrics.Panel.consoleTabRow)
            Divider()
            ZStack {
                if app.bottomPanelTab == .console {
                    ConsoleView(console: app.console, onRun: onRun)
                }
                ForEach(shownTerminals, id: \.self) { url in
                    let isVisible = app.bottomPanelTab == .terminal && url == repositoryURL
                    makeTerminal(url, app.terminalFocusRequest(for: url))
                        .opacity(isVisible ? 1 : 0)
                        .allowsHitTesting(isVisible)
                        .accessibilityHidden(!isVisible)
                        .onAppear { startedTerminals.insert(url) }
                }
            }
        }
        .onChange(of: terminalURLs) { _, urls in startedTerminals.formIntersection(urls) }
    }

    private var shownTerminals: [URL] {
        let urls = terminalURLs.contains(repositoryURL) ? terminalURLs : terminalURLs + [repositoryURL]
        return urls.filter { startedTerminals.contains($0) || ($0 == repositoryURL && app.bottomPanelTab == .terminal) }
    }

    private func tabButton(_ tab: AppViewModel.BottomPanelTab) -> some View {
        let isSelected = app.bottomPanelTab == tab
        return Button { app.selectBottomPanelTab(tab) } label: {
            Text(tab.rawValue)
                .font(Metrics.Font.title.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Palette.Text.primary.color : Palette.Text.secondary.color)
                .padding(.horizontal, Metrics.Spacing.m)
                .frame(height: Metrics.Panel.consoleTab)
                .background(isSelected ? Palette.Text.primary.color.opacity(Palette.Ink.hover) : Color.clear, in: RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.rawValue)
        .accessibilityIdentifier(tab == .console ? "bottom.console" : "bottom.terminal")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct ConsoleControls: View {
    @Bindable var console: ConsoleViewModel

    var body: some View {
        HStack(spacing: Metrics.Spacing.s) {
            Toggle("Show read commands", isOn: $console.showsReadCommands)
                .toggleStyle(.checkbox)
                .foregroundStyle(Palette.Text.secondary.color)
                .controlSize(.small)
                .help("Also list the read-only commands the app runs to refresh its views")
                .accessibilityIdentifier("console.showReads")
            PanelIconButton(title: "Clear", systemImage: "trash", help: "Clear the console", identifier: "console.clear") { console.clear() }
            Divider()
                .frame(height: Metrics.Toolbar.separatorHeight)
        }
        .font(Metrics.Font.body)
    }
}

struct PanelIconButton: View {
    let title: String
    let systemImage: String
    var help: String? = nil
    let identifier: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: Metrics.Icon.regular))
                .foregroundStyle(Palette.Text.secondary.color)
                .frame(width: Metrics.HitTarget.icon, height: Metrics.HitTarget.icon)
                .background(isHovered ? Palette.Text.primary.color.opacity(Palette.Ink.hover) : Color.clear, in: RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help ?? title)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }
}

struct PanelResizeHandle: View {
    @Binding var height: CGFloat
    var range: ClosedRange<CGFloat> = 100...700
    var growsDownward = false
    var identifier = "bottom.resize"
    @State private var startHeight: CGFloat?

    var body: some View {
        Divider()
            .frame(height: 1)
            .overlay(Color.clear.frame(height: Metrics.HitTarget.resizeHandle).contentShape(Rectangle()))
            .onHover { inside in
                if inside { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        let start = startHeight ?? height
                        startHeight = start
                        let delta = growsDownward ? value.translation.height : -value.translation.height
                        height = min(max(start + delta, range.lowerBound), range.upperBound)
                    }
                    .onEnded { _ in startHeight = nil }
            )
            .accessibilityIdentifier(identifier)
    }
}
