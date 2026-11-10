import AppKit
import MorkDomain
import SwiftUI

struct RepositoryView: View {
    @Bindable var viewModel: RepositoryViewModel
    let console: ConsoleViewModel
    let app: AppViewModel
    let makeTerminal: TerminalFactory
    var isBehindManager = false
    @State private var detailHeight: CGFloat = 0
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var sidebar = AdaptiveSidebar()
    @State private var showsOverlaySidebar = false
    @State private var isSidebarAnimating = false

    var body: some View {
        PaneSplit(
            .horizontal,
            key: PaneSplitKey.sidebarWidth,
            defaultSize: Metrics.Sidebar.idealWidth,
            range: Metrics.Sidebar.minimumWidth...Metrics.Sidebar.maximumWidth,
            mainMinimum: Metrics.Window.minimumDetailWidth,
            identifier: "sidebar.resize",
            isSideVisible: columnVisibility != .detailOnly
        ) {
            ZStack {
                ForEach(app.liveTabs) { tab in
                    RepositorySidebar(viewModel: tab, app: app)
                        .liveTab(isActive: tab === viewModel)
                }
            }
            .padding(.top, Metrics.Toolbar.bandHeight - Metrics.Spacing.s)
            .padding(.horizontal, Metrics.Sidebar.windowInset)
            .padding(.bottom, Metrics.Sidebar.windowInset)
            .background {
                SidebarWindowFrame()
                    .padding(Metrics.Sidebar.windowInset)
                    .accessibilityHidden(true)
            }
        } main: {
            VStack(spacing: 0) {
                RepositoryToolbarBar(viewModel: viewModel, app: app, isSidebarHidden: columnVisibility == .detailOnly && !showsOverlaySidebar, isStageFrozen: isSidebarAnimating, toggleSidebar: toggleSidebar)
                    .padding(.leading, columnVisibility == .detailOnly ? max(Metrics.Toolbar.margin, Metrics.Toolbar.trafficLightsWidth) : Metrics.Toolbar.margin)
                    .padding(.trailing, Metrics.Toolbar.margin)
                    .frame(height: Metrics.Toolbar.bandHeight)
                    .frame(maxWidth: .infinity)
                    .background(WindowDragArea())
                    .background(Palette.Surface.window.color)
                ToolbarDivider(viewModel: viewModel, showsTabBar: app.showsTabBar)
                if app.showsTabBar {
                    RepositoryTabBar(app: app, onNew: app.openManagerTab)
                }
                ZStack {
                    ForEach(app.liveTabs) { tab in
                        RepositoryDetail(viewModel: tab, app: app, commitDetailsLayout: app.commitDetailsLayout)
                            .environment(\.isActiveRepositoryTab, tab === viewModel)
                            .liveTab(isActive: tab === viewModel)
                    }
                }
                .overlay(alignment: .leading) {
                    if showsOverlaySidebar {
                        OverlaySidebar(viewModel: viewModel, app: app, dismiss: dismissOverlaySidebar)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                if app.showsBottomPanel {
                    PanelResizeHandle(height: bottomPanelHeight, range: Metrics.Panel.minimumHeight...bottomPanelMaximumHeight)
                    BottomPanel(app: app, repositoryURL: viewModel.url, terminalURLs: app.liveTabs.map(\.url), makeTerminal: makeTerminal, onRun: { command in Task { await viewModel.runCommand(command) } })
                        .frame(height: bottomPanelFrameHeight)
                }
            }
            .frame(minWidth: Metrics.Window.minimumDetailWidth)
            .ignoresSafeArea(.container, edges: .top)
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }, action: { detailHeight = $0 })
            .sheet(item: $viewModel.fileInspector) { FileInspectorSheet(viewModel: viewModel, inspector: $0) }
            .sheet(item: $viewModel.bisectLog) { BisectLogSheet(log: $0) }
            .sheet(item: $viewModel.statistics) { StatisticsSheet(session: $0) }
        }
        .ignoresSafeArea(.container, edges: .top)
        .navigationTitle(viewModel.name)
        .navigationSubtitle(viewModel.headTitle)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }, action: windowWidthChanged)
        .background {
            if showsOverlaySidebar {
                SidebarSelectionObserver(viewModel: viewModel, onChange: dismissOverlaySidebar)
            }
        }
        .background(TrafficLightsCentering())
        .background(FilePreviewHost(viewModel: viewModel))
        .background(CommitPreviewHost(viewModel: viewModel))
        .background(ConflictWindowHost(viewModel: viewModel))
        .focusedSceneValue(\.repository, isBehindManager ? nil : viewModel)
        .onChange(of: viewModel.id) { NSApp.keyWindow?.makeFirstResponder(nil) }
        .sheet(item: $viewModel.sheet) { sheet in
            switch sheet {
            case .branch:
                CreateBranchSheet(viewModel: viewModel)
            case .tag:
                CreateTagSheet(viewModel: viewModel, target: .head, identifier: "tagSheet")
            case .stash:
                TextInputSheet(title: "Stash Current Changes", placeholder: "Description (optional)", secondaryPlaceholder: nil, confirmTitle: "Stash", identifier: "stashSheet", message: "Set your uncommitted changes aside and restore a clean working tree. Apply them later from the Stashes section.", glyph: "archivebox", command: DialogCommands.stash, allowsEmpty: true) { message, _ in
                    Task { await viewModel.stash(message: message) }
                }
            case .pull:
                PullOptionsSheet(viewModel: viewModel)
            case .push:
                PushOptionsSheet(viewModel: viewModel)
            case .fetch:
                FetchOptionsSheet(viewModel: viewModel)
            case .worktree:
                AddWorktreeSheet(form: viewModel.makeWorktreeForm()) { request in
                    Task { await viewModel.addWorktree(path: request.path, checkout: request.checkout) }
                }
            case .startLeanBranch:
                TextInputSheet(title: "Start Branch on '\(viewModel.leanBase?.name ?? "")'", placeholder: "feature/branch-name", secondaryPlaceholder: nil, confirmTitle: "Start", identifier: "leanStartSheet") { name, _ in
                    Task { await viewModel.startLeanBranch(named: name) }
                }
            case .finishLeanBranch:
                LeanFinishSheet(viewModel: viewModel)
            }
        }
        .workingCopyToolsPresentation(viewModel)
        .errorAlert($viewModel.errorMessage)
        .repositorySettingsPresentation(viewModel)
        .advancedToolsPresentation(viewModel)
        .customCommandConfirmation(viewModel)
    }

    private func toggleSidebar() {
        if sidebar.isNarrow {
            withAnimation(Self.sidebarAnimation) { showsOverlaySidebar.toggle() }
            return
        }
        animateSidebar { columnVisibility = sidebar.toggled(from: columnVisibility) }
    }

    private func windowWidthChanged(_ width: CGFloat) {
        guard let visibility = sidebar.windowWidthChanged(width, current: columnVisibility) else { return }
        if !sidebar.isNarrow, showsOverlaySidebar { showsOverlaySidebar = false }
        guard visibility != columnVisibility else { return }
        animateSidebar { columnVisibility = visibility }
    }

    private func dismissOverlaySidebar() {
        guard showsOverlaySidebar else { return }
        withAnimation(Self.sidebarAnimation) { showsOverlaySidebar = false }
    }

    private func animateSidebar(_ change: () -> Void) {
        isSidebarAnimating = true
        withAnimation(Self.sidebarAnimation, change)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.sidebarAnimationDuration + 0.05) { isSidebarAnimating = false }
    }

    private static let sidebarAnimationDuration = 0.25
    private static let sidebarAnimation = Animation.easeInOut(duration: sidebarAnimationDuration)

    private var bottomPanelHeight: Binding<CGFloat> {
        Binding(get: { bottomPanelFrameHeight }, set: { app.bottomPanelHeight = Double($0) })
    }

    private var bottomPanelMaximumHeight: CGFloat {
        RepositoryPaneLayout.bottomPanelMaximumHeight(detailHeight: detailHeight)
    }

    private var bottomPanelFrameHeight: CGFloat {
        RepositoryPaneLayout.bottomPanelHeight(saved: app.savedBottomPanelHeight.map { CGFloat($0) }, detailHeight: detailHeight)
    }
}

struct AdaptiveSidebar: Equatable {
    static let hysteresis: CGFloat = 24

    private(set) var isNarrow = false
    private(set) var userCollapsed = false

    mutating func windowWidthChanged(_ width: CGFloat, current: NavigationSplitViewVisibility) -> NavigationSplitViewVisibility? {
        guard width > 0 else { return nil }
        let threshold = Metrics.Window.sidebarAutoHideWidth
        if !isNarrow, width < threshold {
            isNarrow = true
            return .detailOnly
        }
        if isNarrow, width >= threshold + Self.hysteresis {
            isNarrow = false
            return userCollapsed ? .detailOnly : .all
        }
        return nil
    }

    mutating func toggled(from current: NavigationSplitViewVisibility) -> NavigationSplitViewVisibility {
        let next: NavigationSplitViewVisibility = current == .detailOnly ? .all : .detailOnly
        if !isNarrow { userCollapsed = next == .detailOnly }
        return next
    }
}

struct TrafficLightsCentering: NSViewRepresentable {
    func makeNSView(context: Context) -> Observer {
        Observer()
    }

    func updateNSView(_ view: Observer, context: Context) {
        view.center()
    }

    final class Observer: NSView {
        private var standardButtonOrigins: [NSWindow.ButtonType: CGFloat] = [:]

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            NotificationCenter.default.removeObserver(self)
            standardButtonOrigins = [:]
            guard let window else { return }
            for name in [NSWindow.didResizeNotification, NSWindow.didEndLiveResizeNotification, NSWindow.didExitFullScreenNotification, NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification, NSWindow.didUpdateNotification] {
                NotificationCenter.default.addObserver(self, selector: #selector(scheduleCenter), name: name, object: window)
            }
            DispatchQueue.main.async { [weak self] in self?.center() }
        }

        override func layout() {
            super.layout()
            center()
        }

        @objc private func scheduleCenter() {
            center()
            DispatchQueue.main.async { [weak self] in self?.center() }
        }

        private func targetOrigins() -> [(NSButton, NSPoint)] {
            guard let window, let close = window.standardWindowButton(.closeButton) else { return [] }
            let height = Metrics.Toolbar.bandHeight
            let standardLeading = standardButtonOrigins[.closeButton] ?? close.frame.minX
            let offset = Metrics.Sidebar.windowControlsLeading - standardLeading
            return [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].compactMap { kind in
                guard let button = window.standardWindowButton(kind), let standardX = standardButtonOrigins[kind] else { return nil }
                return (button, NSPoint(x: standardX + offset, y: ((height - button.frame.height) / 2).rounded()))
            }
        }

        @objc func center() {
            guard let window, !window.styleMask.contains(.fullScreen), let close = window.standardWindowButton(.closeButton), let titlebar = close.superview, let container = titlebar.superview, let frame = container.superview else { return }
            let height = Metrics.Toolbar.bandHeight
            let target = NSRect(x: 0, y: frame.bounds.height - height, width: frame.bounds.width, height: height)
            if container.frame != target {
                container.frame = target
                titlebar.frame = container.bounds
            }
            for kind in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                guard let button = window.standardWindowButton(kind) else { continue }
                if standardButtonOrigins[kind] == nil { standardButtonOrigins[kind] = button.frame.minX }
            }
            for (button, origin) in targetOrigins() where button.frame.origin != origin {
                button.setFrameOrigin(origin)
            }
        }
    }
}

struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView {
        DragView()
    }

    func updateNSView(_ view: DragView, context: Context) {}

    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }

        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            if event.clickCount == 2 {
                let action = UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick")
                if action == "Minimize" { window.miniaturize(nil) } else if action != "None" { window.zoom(nil) }
                return
            }
            window.performDrag(with: event)
        }
    }
}

private struct RepositoryToolbarBar: View {
    let viewModel: RepositoryViewModel
    let app: AppViewModel
    let isSidebarHidden: Bool
    let isStageFrozen: Bool
    let toggleSidebar: () -> Void

    @State private var stage = 0
    @State private var tracker = ToolbarStageTracker()

    var body: some View {
        bar(ToolbarDensity.stages[stage], isLive: true)
            .frame(minWidth: 0, maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self, of: { $0.size.width }, action: { width in apply(animated: true) { $0.setWidth(width) } })
            .background {
                ZStack {
                    ForEach(ToolbarDensity.stages.indices, id: \.self) { index in
                        bar(ToolbarDensity.stages[index], isLive: false)
                            .fixedSize()
                            .onGeometryChange(for: CGFloat.self, of: { $0.size.width }, action: { width in apply(animated: false) { $0.setRequired(width, at: index) } })
                    }
                }
                .hidden()
                .accessibilityHidden(true)
            }
            .onChange(of: isStageFrozen, initial: true) { _, frozen in apply(animated: true) { frozen ? $0.freeze() : $0.thaw() } }
    }

    private func apply(animated: Bool, _ change: (inout ToolbarStageState) -> Void) {
        change(&tracker.state)
        guard tracker.state.stage != stage else { return }
        if animated {
            withAnimation(.easeInOut(duration: Metrics.Dropdown.fade)) { stage = tracker.state.stage }
        } else {
            stage = tracker.state.stage
        }
    }

    private func bar(_ density: ToolbarDensity, isLive: Bool) -> some View {
        ToolbarBarLayout {
            leading(density)
            center(density, isLive: isLive)
            trailing(density)
        }
        .environment(\.toolbarShowsCaptions, density.showsCaptions)
    }

    private func leading(_ density: ToolbarDensity) -> some View {
        HStack(spacing: Metrics.Toolbar.groupSpacing) {
            ToolbarCaptionButton(title: "Sidebar", systemImage: "sidebar.left", isCompact: true, showsCaption: false, action: toggleSidebar)
                .help(isSidebarHidden ? "Show Sidebar" : "Hide Sidebar")
                .accessibilityIdentifier("toolbar.sidebar")
            if !density.collapsesSecondary {
                ToolbarCaptionButton(title: "Quick Launch", systemImage: "bolt") { app.toggleQuickLaunch() }
                    .help("Quick Launch (⌘P)")
                    .accessibilityIdentifier("toolbar.quickLaunch")
            }
            HStack(spacing: 0) {
                ToolbarCaptionButton(title: "Fetch", systemImage: "arrowshape.turn.up.left", isCompact: true, isRunning: viewModel.isRunning(.fetch), symbolRotation: .degrees(-90)) { Task { await viewModel.fetch() } }
                    .help("git fetch --prune")
                    .accessibilityIdentifier("toolbar.fetch")
                ToolbarGroupSeparator()
                ToolbarCaptionButton(title: "Pull", systemImage: "arrowshape.turn.up.left.fill", isCompact: true, isRunning: viewModel.isRunning(.pull), badge: viewModel.currentBranch?.behind ?? 0, symbolRotation: .degrees(-90)) { viewModel.sheet = .pull }
                    .help("Pull… choose the remote branch, merge or rebase")
                    .disabled(viewModel.isDetachedHead)
                    .accessibilityIdentifier("toolbar.pull")
                ToolbarGroupSeparator()
                ToolbarCaptionButton(title: "Push", systemImage: "arrowshape.turn.up.left.fill", isCompact: true, isRunning: viewModel.isRunning(.push), badge: viewModel.currentBranch?.ahead ?? 0, symbolRotation: .degrees(90)) { viewModel.sheet = .push }
                    .help("Push… choose the branch, the remote, tags and force push")
                    .disabled(viewModel.isDetachedHead)
                    .accessibilityIdentifier("toolbar.push")
            }
            HStack(spacing: ToolbarCaptionButton.spacing) {
                ToolbarCaptionButton(title: "Stash", systemImage: "archivebox") { viewModel.sheet = .stash }
                    .help("Stash current changes")
                    .accessibilityIdentifier("toolbar.stash")
                if density.collapsesSecondary {
                    ToolbarMoreButton(app: app, viewModel: viewModel)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func center(_ density: ToolbarDensity, isLive: Bool) -> some View {
        HStack(spacing: ToolbarCaptionButton.spacing) {
            RepositoryPicker(viewModel: viewModel, minimumWidth: density.pickerMinimum, maximumWidth: density.pickerMaximum, opensOnRequest: isLive) { worktree in Task { await app.openWorktree(worktree) } }
                .padding(.trailing, Metrics.Spacing.xs)
            BranchMenuButton(viewModel: viewModel)
        }
        .accessibilityElement(children: .contain)
    }

    private func trailing(_ density: ToolbarDensity) -> some View {
        HStack(spacing: ToolbarCaptionButton.spacing) {
            OpenInButton(viewModel: viewModel, showTerminal: app.showTerminal)
            if app.isPrimaryWindow { WorkspacesButton(app: app) }
            ToolbarCaptionButton(title: "Console", systemImage: "rectangle.bottomthird.inset.filled", isActive: app.showsBottomPanel) { app.toggleBottomPanel() }
                .help(app.showsBottomPanel ? "Hide Git Console (⇧⌘C)" : "Show Git Console (⇧⌘C)")
                .accessibilityIdentifier("toolbar.console")
        }
        .accessibilityElement(children: .contain)
    }
}

final class ToolbarStageTracker {
    var state = ToolbarStageState()
}

struct ToolbarStageState: Equatable {
    private(set) var stage = 0
    private(set) var width: CGFloat = 0
    private(set) var required: [CGFloat?] = Array(repeating: nil, count: ToolbarDensity.stages.count)
    private(set) var isFrozen = false
    private(set) var computations = 0

    mutating func setWidth(_ value: CGFloat) {
        width = value
        recompute()
    }

    mutating func setRequired(_ value: CGFloat, at index: Int) {
        guard required.indices.contains(index) else { return }
        required[index] = value
        recompute()
    }

    mutating func freeze() {
        isFrozen = true
    }

    mutating func thaw() {
        guard isFrozen else { return }
        isFrozen = false
        recompute()
    }

    private mutating func recompute() {
        guard !isFrozen, width > 0 else { return }
        let measured = required.compactMap { $0 }
        guard measured.count == required.count else { return }
        computations += 1
        stage = ToolbarDensity.stage(for: width, required: measured, current: stage)
    }
}

private struct OverlaySidebar: View {
    let viewModel: RepositoryViewModel
    let app: AppViewModel
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            RepositorySidebar(viewModel: viewModel, app: app)
                .frame(width: Metrics.Sidebar.idealWidth)
                .background(Palette.Surface.sidebar.color)
                .overlay(alignment: .trailing) { Hairline(isVertical: true) }
                .modifier(PopoverShadow())
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("sidebar.overlay")
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(perform: dismiss)
                .accessibilityHidden(true)
        }
        .onExitCommand(perform: dismiss)
    }
}

struct ToolbarDensity: Hashable {
    static let hysteresis: CGFloat = 16

    let showsCaptions: Bool
    let collapsesSecondary: Bool
    let pickerMinimum: CGFloat
    let pickerMaximum: CGFloat

    static let stages: [ToolbarDensity] = [
        ToolbarDensity(showsCaptions: true, collapsesSecondary: false, pickerMinimum: Metrics.Control.pickerMinimumWidth, pickerMaximum: Metrics.Control.pickerMaxWidth),
        ToolbarDensity(showsCaptions: false, collapsesSecondary: false, pickerMinimum: Metrics.Control.pickerMinimumWidth, pickerMaximum: Metrics.Control.pickerIconOnlyMaxWidth),
        ToolbarDensity(showsCaptions: false, collapsesSecondary: true, pickerMinimum: Metrics.Control.pickerMinimumWidth, pickerMaximum: Metrics.Control.pickerIconOnlyMaxWidth),
        ToolbarDensity(showsCaptions: false, collapsesSecondary: true, pickerMinimum: Metrics.Control.pickerFloorWidth, pickerMaximum: Metrics.Control.pickerIconOnlyMaxWidth)
    ]

    static func stage(for width: CGFloat, required: [CGFloat], current: Int) -> Int {
        for index in required.indices {
            let threshold = required[index] + (index < current ? hysteresis : 0)
            if width >= threshold { return index }
        }
        return required.count - 1
    }
}

private struct ToolbarMoreButton: View {
    let app: AppViewModel
    let viewModel: RepositoryViewModel
    @State private var dropdown = DropdownPanel()

    var body: some View {
        ToolbarCaptionButton(title: "More", systemImage: "ellipsis", showsMenuIndicator: true) {
            dropdown.show(identifier: "toolbarMore.menu", [
                MenuEntry(title: "Quick Launch", systemImage: "bolt", keyEquivalent: "", identifier: "toolbarMore.quickLaunch") { app.toggleQuickLaunch() },
            ])
        }
        .background(DropdownAnchorView(panel: dropdown))
        .help("Quick Launch")
        .accessibilityIdentifier("toolbar.more")
    }
}

struct ToolbarBarLayout: Layout {
    var gap = Metrics.Spacing.m

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 3 else { return .zero }
        let leading = subviews[0].sizeThatFits(.unspecified)
        let center = subviews[1].sizeThatFits(ProposedViewSize(width: 0, height: nil))
        let trailing = subviews[2].sizeThatFits(.unspecified)
        let minimum = leading.width + center.width + trailing.width + gap * 2
        let height = max(leading.height, center.height, trailing.height)
        return CGSize(width: proposal.width.map { max($0, minimum) } ?? minimum, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        let leading = subviews[0].sizeThatFits(.unspecified)
        let trailing = subviews[2].sizeThatFits(.unspecified)
        let minimum = subviews[1].sizeThatFits(ProposedViewSize(width: 0, height: nil)).width
        let maximum = subviews[1].sizeThatFits(ProposedViewSize(width: .infinity, height: nil)).width
        let start = bounds.minX + leading.width + gap
        let end = bounds.maxX - trailing.width - gap
        let width = max(minimum, min(maximum, end - start))
        let x = min(max(bounds.midX - width / 2, start), end - width)
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(leading))
        subviews[1].place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(width: width, height: bounds.height))
        subviews[2].place(at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing, proposal: ProposedViewSize(trailing))
    }
}

private struct RepositorySidebar: View {
    let viewModel: RepositoryViewModel
    let app: AppViewModel

    var body: some View {
        SidebarView(viewModel: viewModel, onOpenRepository: { url in Task { await app.open(url) } })
    }
}

private struct RepositoryDetail: View {
    let viewModel: RepositoryViewModel
    let app: AppViewModel
    let commitDetailsLayout: CommitDetailsLayout
    @State private var historyListHeight: CGFloat?
    @State private var commitBrowserHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.hasLoaded {
                RepositoryLoadingView(name: viewModel.name)
            } else {
                if viewModel.repositoryState != .clean {
                    StateBanner(viewModel: viewModel)
                }
                if viewModel.isBisecting {
                    BisectBanner(viewModel: viewModel)
                }
                ZStack {
                    PaneSplit(
                        .horizontal,
                        key: PaneSplitKey.changesListWidth,
                        defaultSize: Metrics.Changes.listIdealWidth,
                        range: Metrics.Changes.listMinimumWidth...Metrics.Changes.listMaximumWidth,
                        mainMinimum: Metrics.Changes.detailMinimumWidth,
                        identifier: "changes.resize"
                    ) {
                        ChangesView(viewModel: viewModel)
                    } main: {
                        VStack(spacing: 0) {
                            if let resolver = viewModel.conflictResolver {
                                ConflictResolverView(resolver: resolver, repository: viewModel)
                                    .id(ObjectIdentifier(resolver))
                                    .frame(maxHeight: .infinity)
                            } else {
                                DetailView(viewModel: viewModel, showsFileHeaderBar: true)
                                    .frame(maxHeight: .infinity)
                            }
                            Hairline()
                            if let note = viewModel.commitBlockedNote {
                                ConflictCommitStrip(note: note)
                            } else {
                                CommitComposer(viewModel: viewModel)
                            }
                        }
                    }
                    .frame(minHeight: Metrics.Changes.minimumHeight, maxHeight: .infinity)
                    .livePane(isActive: viewModel.pane == .changes)
                    commitBrowser { HistoryView(viewModel: viewModel) }
                        .livePane(isActive: viewModel.pane == .history)
                    if viewModel.pane == .reflog {
                        commitBrowser { ReflogView(viewModel: viewModel) }
                    }
                }
                .background(PaneFocusReset(pane: viewModel.pane))
            }
        }
    }

    private func commitBrowser<Content: View>(@ViewBuilder list: () -> Content) -> some View {
        VStack(spacing: 0) {
            list()
                .frame(height: visibleHistoryListHeight)
            PanelResizeHandle(height: Binding(get: { visibleHistoryListHeight }, set: { historyListHeight = $0 }), range: Metrics.HistoryPane.listMinimumHeight...Metrics.HistoryPane.listMaximumHeight, growsDownward: true, identifier: "history.resize")
            CommitInfoView(viewModel: viewModel, layout: commitDetailsLayout) { app.commitDetailsLayout.filesPlacement = commitDetailsLayout.filesPlacement.toggled }
                .frame(minHeight: Metrics.HistoryPane.detailsFrameMinimumHeight, maxHeight: .infinity)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("history.details")
        }
        .frame(minHeight: Metrics.HistoryPane.browserMinimumHeight, maxHeight: .infinity)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }, action: { commitBrowserHeight = $0 })
    }

    private var visibleHistoryListHeight: CGFloat {
        RepositoryPaneLayout.historyListHeight(saved: historyListHeight, browserHeight: commitBrowserHeight)
    }
}

private struct RepositoryLoadingView: View {
    let name: String

    var body: some View {
        VStack(spacing: Metrics.Spacing.s) {
            ProgressView()
                .controlSize(.small)
            Text("Loading \(name)…")
                .font(Metrics.Font.body)
                .foregroundStyle(Palette.Text.secondary.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("repository.loading")
    }
}

private struct SidebarSelectionObserver: View {
    let viewModel: RepositoryViewModel
    let onChange: () -> Void

    var body: some View {
        Color.clear
            .onChange(of: viewModel.pane) { onChange() }
            .onChange(of: viewModel.sidebarItem) { onChange() }
    }
}

struct PaneFocusReset: NSViewRepresentable {
    let pane: RepositoryViewModel.Pane

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ view: NSView, context: Context) {
        let previous = context.coordinator.pane
        context.coordinator.pane = pane
        guard let previous, previous != pane, let window = view.window, let responder = window.firstResponder as? NSView, responder.window === window else { return }
        let paneFrame = view.convert(view.bounds, to: nil)
        let responderFrame = responder.convert(responder.visibleRect, to: nil)
        guard paneFrame.contains(NSPoint(x: responderFrame.midX, y: responderFrame.midY)) else { return }
        window.makeFirstResponder(nil)
    }

    final class Coordinator {
        var pane: RepositoryViewModel.Pane?
    }
}

private extension View {
    func livePane(isActive: Bool) -> some View {
        liveTab(isActive: isActive)
            .allowsHitTesting(isActive)
    }

    func liveTab(isActive: Bool) -> some View {
        frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
            .opacity(isActive ? 1 : 0)
            .offset(x: isActive ? 0 : Metrics.Window.parkedOffset)
            .accessibilityHidden(!isActive)
            .zIndex(isActive ? 1 : 0)
    }
}

struct OpenInButton: View {
    let viewModel: RepositoryViewModel
    let showTerminal: () -> Void
    @State private var dropdown = DropdownPanel()

    var body: some View {
        ToolbarCaptionButton(title: "Open in", systemImage: "arrow.up.forward.app", showsMenuIndicator: true) {
            dropdown.show(identifier: "openIn.menu", Self.entries(viewModel: viewModel, showTerminal: showTerminal))
        }
        .background(DropdownAnchorView(panel: dropdown))
        .help("Open the repository in another app")
        .accessibilityIdentifier("toolbar.openIn")
    }

    static func entries(viewModel: RepositoryViewModel, showTerminal: @escaping () -> Void) -> [MenuEntry] {
        [
            MenuEntry(title: "Finder", systemImage: "folder", identifier: "openIn.finder") {
                NSWorkspace.shared.activateFileViewerSelecting([viewModel.url])
            },
            MenuEntry(title: "Terminal Tab", systemImage: "terminal", identifier: "openIn.terminalTab", action: showTerminal),
            MenuEntry(title: viewModel.terminalAppName, systemImage: "apple.terminal.on.rectangle", identifier: "openIn.terminalApp") {
                Task { await viewModel.openRepositoryInTerminalApp() }
            },
            MenuEntry(title: viewModel.editorName ?? "External Editor", systemImage: "chevron.left.forwardslash.chevron.right", identifier: "openIn.editor") {
                Task { await viewModel.openRepositoryInEditor() }
            }
        ]
    }
}

private struct RepositoryPicker: View {
    let viewModel: RepositoryViewModel
    let minimumWidth: CGFloat
    let maximumWidth: CGFloat
    let opensOnRequest: Bool
    let onOpenWorktree: (Worktree) -> Void
    @State private var dropdown = DropdownPanel()
    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.Radius.card, style: .continuous)
        let summary = viewModel.currentBranch?.trackSummary
        Button(action: showMenu) {
            HStack(spacing: Metrics.Spacing.s) {
                if let summary {
                    syncCounts(summary).hidden()
                }
                VStack(spacing: Metrics.Spacing.xxs) {
                    Text(viewModel.name)
                        .font(Metrics.Font.title.weight(.semibold))
                        .foregroundStyle(Palette.Text.primary.color)
                        .truncationMode(.middle)
                    HStack(spacing: Metrics.Spacing.xs) {
                        Image(systemName: viewModel.isDetachedHead ? "exclamationmark.triangle.fill" : "arrow.triangle.branch")
                            .font(Metrics.Font.label)
                            .foregroundStyle(viewModel.isDetachedHead ? Palette.Status.conflict.ink.color : Palette.Text.secondary.color)
                        Text(viewModel.headTitle)
                            .font(Metrics.Font.caption)
                            .truncationMode(.middle)
                        Group {
                            if viewModel.showsActivity {
                                ProgressView().controlSize(.mini)
                            } else {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: Metrics.Icon.menuIndicator, weight: .bold))
                            }
                        }
                        .frame(width: Metrics.Spacing.m, height: Metrics.Spacing.m)
                    }
                    .foregroundStyle(Palette.Text.secondary.color)
                }
                .frame(maxWidth: .infinity)
                if let summary {
                    syncCounts(summary)
                }
            }
            .lineLimit(1)
            .padding(.horizontal, Metrics.Spacing.m)
            .frame(minWidth: minimumWidth, idealWidth: Metrics.Control.pickerWidth, maxWidth: maximumWidth)
            .frame(height: Metrics.Control.picker)
            .background {
                shape.fill(Palette.Surface.window.color)
                    .overlay(shape.fill(Palette.Text.primary.color.opacity(isHovered ? Palette.Ink.hover : 0)))
            }
            .overlay(shape.strokeBorder(Palette.Surface.border.color, lineWidth: Metrics.Line.hairline))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .background(DropdownAnchorView(panel: dropdown))
        .help("Check out a branch")
        .accessibilityLabel("\(viewModel.name), \(viewModel.headTitle)")
        .accessibilityValue(viewModel.showsActivity ? "busy" : "")
        .accessibilityIdentifier("toolbar.branchPicker")
        .onChange(of: viewModel.branchPickerRequest) {
            if opensOnRequest, !dropdown.isShown { showMenu() }
        }
    }

    private func syncCounts(_ summary: String) -> some View {
        Text(summary)
            .font(Metrics.Font.monoCaption)
            .foregroundStyle(Palette.Text.secondary.color)
            .fixedSize()
    }

    private func showMenu() {
        let worktrees = viewModel.worktreeRows.filter { !$0.worktree.isBare }
        let picker = BranchPickerViewModel(branches: viewModel.localBranches, worktrees: worktrees.count > 1 ? worktrees : [])
        let dropdown = dropdown
        dropdown.toggle(identifier: "branchPicker.window", minimumWidth: Metrics.Dropdown.minimumWidth, matchesAnchorWidth: true) { maximumHeight in
            BranchPickerPanel(
                picker: picker,
                maximumHeight: maximumHeight,
                onCheckout: { branch in Task { await viewModel.checkout(branch) } },
                onOpenWorktree: onOpenWorktree,
                onNewBranch: { viewModel.sheet = .branch },
                onFetch: { Task { await viewModel.fetch() } },
                onClose: { dropdown.close() }
            )
        }
    }
}

private struct StateBanner: View {
    let viewModel: RepositoryViewModel

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Palette.Status.conflict.ink.color)
            Text(text)
                .font(Metrics.Font.body)
                .foregroundStyle(Palette.Text.primary.color)
            Spacer()
            ConflictBannerActions(viewModel: viewModel)
            if viewModel.repositoryState == .merging {
                Button("Abort merge") { Task { await viewModel.abortMerge() } }
                    .accessibilityIdentifier("banner.abortMerge")
            }
            if viewModel.hasRevisionOperation {
                Button("Continue") { Task { await viewModel.continueOperation() } }
                    .disabled(viewModel.hasConflicts)
                    .accessibilityIdentifier("banner.continue")
                Button("Abort") { Task { await viewModel.abortOperation() } }
                    .accessibilityIdentifier("banner.abort")
            }
            if viewModel.isRebasing {
                RebaseBannerActions(viewModel: viewModel)
            }
        }
        .controlSize(.small)
        .padding(.horizontal, Metrics.Spacing.m)
        .padding(.vertical, Metrics.Spacing.s)
        .background(Palette.Status.conflict.tint.color)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("banner.state")
    }

    private var text: String {
        switch viewModel.repositoryState {
        case .merging: "Merging: resolve conflicts, stage, then commit, or abort."
        case .rebasing: "Rebasing: resolve conflicts and stage them, then Continue (git rebase --continue), Skip the commit (git rebase --skip) or Abort (git rebase --abort)."
        case .cherryPicking: "Cherry-picking: resolve conflicts and stage them, then Continue (git cherry-pick --continue) or Abort (git cherry-pick --abort)."
        case .reverting: "Reverting: resolve conflicts and stage them, then Continue (git revert --continue) or Abort (git revert --abort)."
        case .clean: ""
        }
    }
}

struct ToolbarDivider: View {
    let viewModel: RepositoryViewModel
    let showsTabBar: Bool

    static func isVisible(pane: RepositoryViewModel.Pane, showsTabBar: Bool) -> Bool {
        showsTabBar || pane != .history
    }

    var body: some View {
        if Self.isVisible(pane: viewModel.pane, showsTabBar: showsTabBar) {
            Hairline()
        }
    }
}
