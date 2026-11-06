import AppKit
import MorkDomain
import SwiftUI
import UniformTypeIdentifiers

struct RepositoryTabBar: View {
    let app: AppViewModel
    let onNew: () -> Void
    @State private var dragged: URL?
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 0) {
            GeometryReader { proxy in
                let count = CGFloat(max(app.tabs.count + (app.hasManagerTab ? 1 : 0), 1))
                let expandedWidth = app.expandedRepositoryTabWidth
                let width = max(Metrics.RepositoryTab.compactMinimumWidth, min(Metrics.RepositoryTab.compactMaximumWidth, (proxy.size.width - expandedWidth) / max(count - 1, 1)))
                ScrollViewReader { reader in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(Array(app.tabs.enumerated()), id: \.element.url) { index, tab in
                                RepositoryTabItem(
                                    tab: tab,
                                    title: app.title(of: tab),
                                    color: app.appearance(of: tab).color,
                                    mainRepository: app.mainRepository(of: tab),
                                    shortcut: index < 8 ? "⌘\(index + 1)" : nil,
                                    isActive: tab === app.repository,
                                    onSelect: { app.selectTab(tab) },
                                    onClose: { app.closeTab(tab) },
                                    makeMenu: { menu(for: tab) }
                                )
                                .frame(width: tab === app.repository ? expandedWidth : width)
                                .id(tab.url)
                                .onDrag {
                                    dragged = tab.url
                                    return NSItemProvider(object: tab.url.path as NSString)
                                }
                                .onDrop(of: [.text], delegate: RepositoryTabDropDelegate(target: tab, app: app, dragged: $dragged))
                            }
                            if app.hasManagerTab {
                                ManagerTabItem(isActive: app.isManagerActive, onSelect: app.openManagerTab, onClose: app.closeManagerTab)
                                    .frame(width: app.isManagerActive ? expandedWidth : width)
                                    .id("manager")
                            }
                        }
                        .frame(height: proxy.size.height)
                    }
                    .onChange(of: app.repository?.url, initial: true) { _, url in
                        if let url { reader.scrollTo(url) }
                    }
                    .onChange(of: app.isManagerActive, initial: true) { _, active in
                        if active { reader.scrollTo("manager") }
                    }
                }
            }
            NewTabButton(action: onNew)
        }
        .frame(height: Metrics.Panel.tabBar)
        .background(Palette.Surface.sidebar.color)
        .overlay(alignment: .bottom) { Hairline() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tabBar")
    }

    private func menu(for tab: RepositoryViewModel) -> NSMenu {
        var entries = [
            MenuEntry(title: "Close Tab", identifier: "tabMenu.close") { app.closeTab(tab) },
            MenuEntry(title: "Close Other Tabs", identifier: "tabMenu.closeOthers", isEnabled: app.tabs.count > 1) { app.closeOtherTabs(tab) },
            MenuEntry(title: "Close All Tabs", identifier: "tabMenu.closeAll") { app.closeAllTabs() },
            MenuEntry(title: "Move Tab to New Window", identifier: "tabMenu.newWindow") {
                app.moveTabToNewWindow(tab)
                openWindow(id: "main")
            },
            .separator,
            MenuEntry(title: "Open in Terminal", identifier: "tabMenu.terminal") { Task { await tab.openRepositoryInTerminalApp() } },
            MenuEntry(title: "Show in Finder", identifier: "tabMenu.finder") { NSWorkspace.shared.activateFileViewerSelecting([tab.url]) }
        ]
        if app.isPrimaryWindow {
            let others = app.workspaces.filter { $0.id != app.currentWorkspace.id }
            entries += [
                .separator,
                MenuEntry(title: "Move to Workspace", identifier: "tabMenu.workspace", isEnabled: !others.isEmpty, children: WorkspaceMenuTree.build(others).map { workspaceEntry($0, tab: tab) }) {}
            ]
        }
        entries += [.separator, MenuEntry(title: "Rename…", identifier: "tabMenu.rename") { app.renamingTab = tab }]
        let menu = MenuAnchor.menu(entries)
        let colors = NSMenuItem()
        colors.view = TabColorMenuView(selected: app.appearance(of: tab).color) { app.setColor($0, for: tab) }
        menu.addItem(colors)
        return menu
    }

    private func workspaceEntry(_ node: WorkspaceMenuNode, tab: RepositoryViewModel) -> MenuEntry {
        switch node {
        case let .workspace(title, workspace):
            MenuEntry(title: title, identifier: "tabMenu.workspace.\(workspace.name)") { app.moveTab(tab, toWorkspace: workspace.id) }
        case let .folder(title, children):
            MenuEntry(title: title, systemImage: "folder", children: children.map { workspaceEntry($0, tab: tab) }) {}
        }
    }
}

private struct TabCapsule: ViewModifier {
    let isActive: Bool
    let isHovered: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Metrics.Spacing.xs)
            .frame(height: Metrics.Row.tab)
            .background(Palette.Text.primary.color.opacity(isActive ? Palette.Ink.selection : isHovered ? Palette.Ink.hover : 0), in: RoundedRectangle(cornerRadius: Metrics.Radius.small, style: .continuous))
            .padding(.horizontal, Metrics.Spacing.xxs)
            .frame(maxHeight: .infinity)
    }
}

private struct TabCloseButton: View {
    let isVisible: Bool
    let label: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: Metrics.Icon.tabClose, weight: .bold))
                .frame(width: Metrics.HitTarget.inline, height: Metrics.HitTarget.inline)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.Text.secondary.color)
        .opacity(isVisible ? 1 : 0)
        .help("Close Tab (⌘W)")
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}

private struct NewTabButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: Metrics.Icon.small, weight: .medium))
                .foregroundStyle(Palette.Text.secondary.color)
                .frame(width: Metrics.HitTarget.icon, height: Metrics.HitTarget.icon)
                .background(Palette.Text.primary.color.opacity(isHovered ? Palette.Ink.hover : 0), in: RoundedRectangle(cornerRadius: Metrics.Radius.small, style: .continuous))
                .frame(width: Metrics.Panel.tabBar + Metrics.Spacing.s, height: Metrics.Panel.tabBar)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("New Tab with the Repository Manager (⌘T)")
        .accessibilityLabel("New Tab")
        .accessibilityIdentifier("tabBar.new")
    }
}

private struct RepositoryTabItem: View {
    let tab: RepositoryViewModel
    let title: String
    let color: TabColor?
    let mainRepository: URL?
    let shortcut: String?
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let makeMenu: () -> NSMenu
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Metrics.Spacing.xs) {
            TabCloseButton(isVisible: !tab.isBusy && isHovered, label: "Close \(tab.name)", identifier: "tab.\(tab.name).close", action: onClose)
            HStack(spacing: Metrics.Spacing.xs) {
                if let mainRepository {
                    Image(systemName: "square.on.square.dashed")
                        .font(Metrics.Font.label)
                        .foregroundStyle(Palette.Text.secondary.color)
                        .help("Linked worktree of \(mainRepository.lastPathComponent)")
                        .accessibilityLabel("worktree of \(mainRepository.lastPathComponent)")
                        .accessibilityIdentifier("tab.\(tab.name).worktreeBadge")
                }
                if let color {
                    Circle()
                        .fill(Color(nsColor: color.swatch))
                        .frame(width: Metrics.Spacing.s, height: Metrics.Spacing.s)
                        .accessibilityLabel("\(color.rawValue) tag")
                        .accessibilityIdentifier("tab.\(tab.name).color")
                }
                Text(title)
                    .font(Metrics.Font.body.weight(isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? Palette.Text.primary.color : Palette.Text.secondary.color)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)
                if isActive, let mainRepository {
                    Text(mainRepository.lastPathComponent)
                        .font(Metrics.Font.caption)
                        .foregroundStyle(Palette.Text.secondary.color)
                        .lineLimit(1)
                }
                if isActive, let shortcut {
                    Text(shortcut)
                        .font(Metrics.Font.caption)
                        .foregroundStyle(Palette.Text.secondary.color)
                        .fixedSize()
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            ZStack {
                if tab.showsActivity {
                    ProgressView().controlSize(.mini)
                } else if tab.hasTabChanges {
                    Circle()
                        .fill(Palette.Text.secondary.color)
                        .frame(width: Metrics.Spacing.s, height: Metrics.Spacing.s)
                        .help("Uncommitted changes")
                        .accessibilityLabel("Uncommitted changes")
                        .accessibilityIdentifier("tab.\(tab.name).dirty")
                }
            }
            .frame(width: Metrics.HitTarget.inline, height: Metrics.HitTarget.inline)
        }
        .modifier(TabCapsule(isActive: isActive, isHovered: isHovered))
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovered = $0 }
        .help(RecentLocation.title(for: tab.url))
        .overlay(TabClickCatcher(onMiddleClick: onClose, makeMenu: makeMenu))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityValue((isActive ? "active" : "inactive") + (tab.hasTabChanges ? ", uncommitted changes" : ""))
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(.default, onSelect)
        .accessibilityIdentifier("tab.\(tab.name)")
    }
}

private struct ManagerTabItem: View {
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Metrics.Spacing.xs) {
            TabCloseButton(isVisible: isHovered, label: "Close Repository Manager", identifier: "tab.manager.close", action: onClose)
            Text("Repository Manager")
                .font(Metrics.Font.body.weight(isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? Palette.Text.primary.color : Palette.Text.secondary.color)
                .lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Color.clear
                .frame(width: Metrics.HitTarget.inline, height: Metrics.HitTarget.inline)
        }
        .modifier(TabCapsule(isActive: isActive, isHovered: isHovered))
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovered = $0 }
        .overlay(TabClickCatcher(onMiddleClick: onClose) { MenuAnchor.menu([MenuEntry(title: "Close Tab", identifier: "tabMenu.close", action: onClose)]) })
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Repository Manager")
        .accessibilityValue(isActive ? "active" : "inactive")
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(.default, onSelect)
        .accessibilityIdentifier("tab.manager")
    }
}

private struct RepositoryTabDropDelegate: DropDelegate {
    let target: RepositoryViewModel
    let app: AppViewModel
    @Binding var dragged: URL?

    func dropEntered(info: DropInfo) {
        guard let dragged, dragged != target.url,
              let source = app.tabs.firstIndex(where: { $0.url == dragged }),
              let destination = app.tabs.firstIndex(where: { $0 === target }) else { return }
        withAnimation(.easeInOut(duration: Metrics.Dropdown.fade)) { app.moveTab(from: source, to: destination) }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragged = nil
        return true
    }
}

private struct TabClickCatcher: NSViewRepresentable {
    let onMiddleClick: () -> Void
    let makeMenu: () -> NSMenu

    func makeNSView(context: Context) -> CatcherView {
        CatcherView(onMiddleClick: onMiddleClick, makeMenu: makeMenu)
    }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.onMiddleClick = onMiddleClick
        view.makeMenu = makeMenu
    }

    final class CatcherView: NSView {
        var onMiddleClick: () -> Void
        var makeMenu: () -> NSMenu

        init(onMiddleClick: @escaping () -> Void, makeMenu: @escaping () -> NSMenu) {
            self.onMiddleClick = onMiddleClick
            self.makeMenu = makeMenu
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            nil
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            switch NSApp.currentEvent?.type {
            case .otherMouseDown, .otherMouseUp, .rightMouseDown, .rightMouseUp: super.hitTest(point)
            default: nil
            }
        }

        override func otherMouseDown(with event: NSEvent) {
            if event.buttonNumber != 2 { super.otherMouseDown(with: event) }
        }

        override func otherMouseUp(with event: NSEvent) {
            if event.buttonNumber == 2 { onMiddleClick() } else { super.otherMouseUp(with: event) }
        }

        override func menu(for event: NSEvent) -> NSMenu? {
            makeMenu()
        }

        override func rightMouseDown(with event: NSEvent) {
            NSMenu.popUpContextMenu(makeMenu(), with: event, for: self)
        }
    }
}
