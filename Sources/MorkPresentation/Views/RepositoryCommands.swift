import AppKit
import SwiftUI

struct RepositoryFocusedValueKey: FocusedValueKey {
    typealias Value = RepositoryViewModel
}

extension FocusedValues {
    var repository: RepositoryViewModel? {
        get { self[RepositoryFocusedValueKey.self] }
        set { self[RepositoryFocusedValueKey.self] = newValue }
    }
}

public struct RepositoryCommands: Commands {
    @FocusedValue(\.repository) private var repository
    @FocusedValue(\.appModel) private var app

    public init() {}

    public var body: some Commands {
        CommandGroup(before: .toolbar) {
            Button("Show Uncommitted Changes") { repository?.pane = .changes }
                .keyboardShortcut("1", modifiers: [.command, .option])
                .disabled(repository == nil)
            Button("Show All Commits") { repository?.pane = .history }
                .keyboardShortcut("2", modifiers: [.command, .option])
                .disabled(repository == nil)
            Menu("Commit Details") {
                Toggle("Show Commit Header", isOn: commitDetailsBinding(\.showsHeader, default: true))
                Picker("Changed Files", selection: commitDetailsBinding(\.filesPlacement, default: .beside)) {
                    ForEach(CommitDetailsLayout.FilesPlacement.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.inline)
            }
            .disabled(app == nil)
            Divider()
            Button("Refresh") { run { await $0.refresh() } }
                .keyboardShortcut("r")
                .disabled(repository == nil)
            Toggle("Show Raw Diff", isOn: Binding(get: { repository?.showsRawDiff ?? false }, set: { repository?.showsRawDiff = $0 }))
                .disabled(repository == nil)
            Divider()
        }
        CommandMenu("Repository") {
            Button("Commit") { run { await $0.commit() } }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!(repository?.canCommit ?? false))
            Divider()
            Button("Fetch…") { repository?.sheet = .fetch }
                .keyboardShortcut("f", modifiers: [.command, .shift, .option])
                .disabled(repository == nil)
            Button("Quick Fetch") { run { await $0.fetch() } }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(repository == nil)
            Button("Pull…") { repository?.sheet = .pull }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .disabled(repository == nil)
            Button("Quick Pull") { run { await $0.pull() } }
                .keyboardShortcut("l", modifiers: [.command, .shift, .option])
                .disabled(repository == nil)
            Button("Push…") { repository?.sheet = .push }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(repository == nil)
            Button("Quick Push") { run { await $0.push() } }
                .keyboardShortcut("p", modifiers: [.command, .shift, .option])
                .disabled(repository == nil)
            Divider()
            Button("Save Stash…") { repository?.sheet = .stash }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(repository == nil)
            Divider()
            Button("Checkout Branch…") { repository?.requestBranchPicker() }
                .disabled(repository == nil)
            Button("New Branch…") { repository?.sheet = .branch }
                .keyboardShortcut("b", modifiers: [.command, .shift])
                .disabled(repository == nil)
            Button("New Tag…") { repository?.sheet = .tag }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(repository == nil)
            Button("New Worktree…") { repository?.sheet = .worktree }
                .disabled(repository == nil)
            GitFlowMenu(repository: repository)
            LFSMenu(repository: repository)
            Divider()
            Button("Apply Patch…") { run { await $0.beginApplyPatch() } }
                .disabled(repository == nil)
            Divider()
            BisectMenu(repository: repository)
            Divider()
            Button("Show in Finder") { repository.map { NSWorkspace.shared.activateFileViewerSelecting([$0.url]) } }
                .disabled(repository == nil)
            Button("Open in Terminal Tab") { app?.showTerminal() }
                .keyboardShortcut("t", modifiers: [.command, .option])
                .disabled(repository == nil || app == nil)
            Button("Open in \(repository?.terminalAppName ?? "Terminal App")") { run { await $0.openRepositoryInTerminalApp() } }
                .disabled(repository == nil)
            Button("Open in \(repository?.editorName ?? "External Editor")") { run { await $0.openRepositoryInEditor() } }
                .disabled(repository == nil)
            Divider()
            Button("Repository Treemap…") { run { await $0.showTreemap() } }
                .disabled(repository == nil)
            Button("Statistics…") { run { await $0.showStatistics() } }
                .disabled(repository == nil)
            Button("Performance Benchmark…") { repository?.showBenchmark() }
                .disabled(repository == nil)
            Button("Repository Settings…") { run { await $0.showRepositorySettings() } }
                .disabled(repository == nil)
            if let repository {
                CustomCommandsMenu(viewModel: repository, location: .repository)
            }
        }
    }

    private func commitDetailsBinding<Value>(_ keyPath: WritableKeyPath<CommitDetailsLayout, Value>, default fallback: Value) -> Binding<Value> {
        Binding(
            get: { app?.commitDetailsLayout[keyPath: keyPath] ?? fallback },
            set: { app?.commitDetailsLayout[keyPath: keyPath] = $0 }
        )
    }

    private func run(_ action: @escaping @MainActor (RepositoryViewModel) async -> Void) {
        guard let repository else { return }
        Task { await action(repository) }
    }
}
