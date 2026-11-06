import AppKit
import MorkDomain
import SwiftUI

struct RepositoryManagerScreen: View {
    let app: AppViewModel
    @Bindable var manager: RepositoryManagerViewModel
    let onOpen: () -> Void
    let onInitialize: () -> Void

    var body: some View {
        PaneSplit(
            .horizontal,
            key: PaneSplitKey.sidebarWidth,
            defaultSize: Metrics.Sidebar.idealWidth,
            range: Metrics.Sidebar.minimumWidth...Metrics.Sidebar.maximumWidth,
            mainMinimum: Metrics.Window.minimumDetailWidth,
            identifier: "manager.resize",
            isSideVisible: true
        ) {
            RepositoryManagerView(app: app, manager: manager)
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
                band
                    .padding(.horizontal, Metrics.Toolbar.margin)
                    .frame(height: Metrics.Toolbar.bandHeight)
                    .frame(maxWidth: .infinity)
                    .background(WindowDragArea())
                    .background(Palette.Surface.window.color)
                Hairline()
                if app.showsTabBar {
                    RepositoryTabBar(app: app, onNew: app.openManagerTab)
                }
                RepositoryManagerDetail(app: app, manager: manager)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: Metrics.Window.minimumDetailWidth)
            .ignoresSafeArea(.container, edges: .top)
        }
        .ignoresSafeArea(.container, edges: .top)
        .onChange(of: manager.selection, initial: true) { _, selection in
            Task { await manager.loadOverview(for: selection?.url) }
        }
        .navigationTitle("Repository Manager")
        .background(TrafficLightsCentering())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("welcome")
    }

    private var band: some View {
        HStack(spacing: Metrics.Spacing.s) {
            VStack(alignment: .leading, spacing: 0) {
                Text(app.tabs.isEmpty ? "Welcome to Mork" : "Repository Manager")
                    .font(Metrics.Font.title.weight(.semibold))
                    .foregroundStyle(Palette.Text.primary.color)
                Text("Open a repository to start")
                    .font(Metrics.Font.caption)
                    .foregroundStyle(Palette.Text.secondary.color)
            }
            Spacer()
            if app.isPrimaryWindow {
                WorkspacesButton(app: app)
                    .environment(\.toolbarShowsCaptions, true)
            }
            Button("Open…", action: onOpen)
                .buttonStyle(.morkSecondary)
                .keyboardShortcut("o")
                .accessibilityIdentifier("welcome.open")
            Button("Clone…", action: app.showCloneSheet)
                .buttonStyle(.morkSecondary)
                .accessibilityIdentifier("welcome.clone")
            Button("New Repository…", action: onInitialize)
                .buttonStyle(.morkSecondary)
                .help("Create a new repository with git init")
                .accessibilityIdentifier("welcome.init")
        }
        .controlSize(.regular)
    }
}

struct RepositoryManagerDetail: View {
    let app: AppViewModel
    let manager: RepositoryManagerViewModel

    var body: some View {
        if let target = manager.overviewTarget {
            RepositoryOverviewPanel(app: app, manager: manager, repository: target)
        } else {
            VStack(spacing: Metrics.Spacing.l) {
                AppIconTile(size: Metrics.Manager.appIcon)
                Text("Mork")
                    .font(Metrics.Font.display)
                    .foregroundStyle(Palette.Text.primary.color)
                Text("A Git client for learning Git. Every action shows the real git command in the Git Console.")
                    .font(Metrics.Font.title)
                    .foregroundStyle(Palette.Text.secondary.color)
                    .multilineTextAlignment(.center)
                Text("Select a repository on the left to see its summary. Double-click to open it.")
                    .font(Metrics.Font.body)
                    .foregroundStyle(Palette.Text.secondary.color)
                WelcomeLessons(topics: manager.welcomeLessons, onOpen: manager.openLesson)
                    .padding(.top, Metrics.Spacing.xl)
            }
            .padding(Metrics.Spacing.xxl)
            .sheet(item: Binding(get: { manager.lessonBrowser }, set: { manager.lessonBrowser = $0 })) { browser in
                LessonBrowserSheet(viewModel: browser)
            }
        }
    }
}

private struct RepositoryOverviewPanel: View {
    enum Tab: String, CaseIterable, Identifiable {
        case summary = "Summary"
        case statistics = "Statistics"

        var id: String { rawValue }
    }

    let app: AppViewModel
    let manager: RepositoryManagerViewModel
    let repository: URL
    @State private var tab = Tab.summary
    @State private var statistics: StatisticsViewModel?

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.m) {
            header
            HStack(alignment: .top, spacing: Metrics.Spacing.xxxl) {
                facts
                remotes
                Spacer(minLength: 0)
            }
            .opacity(manager.isOverviewStale ? Metrics.Opacity.dimmed : 1)
            Picker("Section", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .accessibilityIdentifier("manager.overview.tab")
            Divider()
            switch tab {
            case .summary:
                ReadmeView(readme: manager.isOverviewStale ? nil : manager.overview?.value.readme)
            case .statistics:
                if let statistics, statistics.repositoryName == repository.lastPathComponent {
                    StatisticsContent(session: statistics)
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding(.horizontal, Metrics.Spacing.xl)
        .padding(.top, Metrics.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: StatisticsKey(repository: repository, tab: tab)) {
            guard tab == .statistics else { return }
            let session = app.makeStatistics(for: repository)
            statistics = session
            await session.load()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("manager.overview")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.xxs) {
            Text(repository.lastPathComponent)
                .font(Metrics.Font.display)
                .foregroundStyle(Palette.Text.primary.color)
                .lineLimit(1)
                .accessibilityIdentifier("manager.overview.name")
            HStack(spacing: Metrics.Spacing.xs) {
                Text(RecentLocation.title(for: repository))
                    .font(Metrics.Font.title)
                    .foregroundStyle(Palette.Text.secondary.color)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([repository])
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.Text.secondary.color)
                .help("Reveal in Finder")
                .accessibilityIdentifier("manager.overview.reveal")
            }
        }
    }

    private var facts: some View {
        let value = manager.overview?.value
        return Grid(alignment: .leading, horizontalSpacing: Metrics.Spacing.s, verticalSpacing: Metrics.Spacing.xs) {
            fact("Changed Files", value.map { "\($0.changedFiles)" }, identifier: "changedFiles")
            fact("Repository Size", value.map { ByteCountFormatter.string(fromByteCount: $0.repositorySizeBytes, countStyle: .file) }, identifier: "size")
            fact("Commits", value.map { "\($0.commitCount)" }, identifier: "commits")
            fact("Initial Commit", value.flatMap(\.initialCommitDate).map(Self.date) ?? value.map { _ in "—" }, identifier: "initialCommit")
            fact("Last Commit", value.flatMap(\.lastCommitDate).map(Self.date) ?? value.map { _ in "—" }, identifier: "lastCommit")
            if let error = manager.overviewError {
                GridRow {
                    Text(error)
                        .foregroundStyle(Palette.Status.deleted.ink.color)
                        .gridCellColumns(2)
                }
            }
        }
        .font(Metrics.Font.body)
        .foregroundStyle(Palette.Text.primary.color)
    }

    private func fact(_ title: String, _ value: String?, identifier: String) -> some View {
        GridRow {
            Text(title)
                .fontWeight(.semibold)
                .foregroundStyle(Palette.Text.secondary.color)
                .gridColumnAlignment(.trailing)
            Text(value ?? "…")
                .monospacedDigit()
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("manager.overview.\(identifier)")
    }

    @ViewBuilder
    private var remotes: some View {
        let list = manager.overview?.value.remotes ?? []
        if !list.isEmpty {
            Grid(alignment: .leading, horizontalSpacing: Metrics.Spacing.l, verticalSpacing: Metrics.Spacing.xs) {
                GridRow {
                    Text("Remotes")
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.Text.secondary.color)
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                }
                ForEach(list, id: \.name) { remote in
                    GridRow {
                        Label(remote.name, systemImage: "network")
                            .labelStyle(.titleAndIcon)
                        if let link = CommitWebLink(remoteURL: remote.fetchURL) {
                            HStack(spacing: Metrics.Spacing.m) {
                                Link(link.host.title, destination: link.repositoryURL)
                                if let issues = link.issuesURL { Link("Issues", destination: issues) }
                                Link(link.host == .gitlab ? "Merge Requests" : "Pull Requests", destination: link.pullRequestsURL)
                            }
                            .foregroundStyle(Palette.Accent.text.color)
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("manager.overview.remote.\(remote.name).links")
                        } else {
                            Text(remote.fetchURL)
                                .foregroundStyle(Palette.Text.secondary.color)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
            }
            .font(Metrics.Font.body)
            .foregroundStyle(Palette.Text.primary.color)
        }
    }

    private static func date(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct StatisticsKey: Hashable {
    let repository: URL
    let tab: RepositoryOverviewPanel.Tab
}

private struct ReadmeView: View {
    let readme: RepositoryReadme?

    var body: some View {
        if let readme {
            let blocks = MarkdownBlocks.parse(readme.text)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Metrics.Spacing.m) {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                        ReadmeBlockView(block: block)
                    }
                    if readme.isTruncated {
                        Text("\(readme.fileName) is longer than 512 KB. Open the file to read the rest.")
                            .font(Metrics.Font.caption)
                            .foregroundStyle(Palette.Text.secondary.color)
                    }
                }
                .frame(maxWidth: Metrics.Manager.readmeWidth, alignment: .leading)
                .font(Metrics.Font.title)
                .foregroundStyle(Palette.Text.primary.color)
                .padding(.vertical, Metrics.Spacing.m)
                .textSelection(.enabled)
            }
            .accessibilityIdentifier("manager.overview.readme")
        } else {
            Text("No README in this repository.")
                .font(Metrics.Font.title)
                .foregroundStyle(Palette.Text.secondary.color)
                .padding(.vertical, Metrics.Spacing.m)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct ReadmeBlockView: View {
    let block: MarkdownBlock

    var body: some View {
        switch block {
        case let .heading(level, text):
            Text(Self.inline(text))
                .font(level == 1 ? Metrics.Font.display : level == 2 ? Metrics.Font.heading : Metrics.Font.title.weight(.semibold))
                .padding(.top, level <= 2 ? Metrics.Spacing.s : 0)
        case let .paragraph(text):
            Text(Self.inline(text))
                .fixedSize(horizontal: false, vertical: true)
        case let .item(depth, marker, text):
            HStack(alignment: .firstTextBaseline, spacing: Metrics.Spacing.s) {
                Text(marker).foregroundStyle(Palette.Text.secondary.color)
                Text(Self.inline(text)).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, CGFloat(depth + 1) * Metrics.Spacing.l)
        case let .code(text):
            Text(text)
                .font(Metrics.Font.monoBody)
                .padding(Metrics.Spacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.Surface.well.color, in: RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous))
        case let .quote(text):
            Text(Self.inline(text))
                .foregroundStyle(Palette.Text.secondary.color)
                .padding(.leading, Metrics.Spacing.s)
                .overlay(alignment: .leading) { Rectangle().fill(Palette.Surface.borderStrong.color).frame(width: Metrics.Manager.quoteBar) }
        case .rule:
            Divider()
        }
    }

    private static func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
}
