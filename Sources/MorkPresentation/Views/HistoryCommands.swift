import MorkDomain
import SwiftUI

public struct HistoryCommands: Commands {
    @FocusedValue(\.repository) private var repository

    public init() {}

    public var body: some Commands {
        CommandGroup(before: .toolbar) {
            Button("Show Reflog") { repository?.pane = .reflog }
                .keyboardShortcut("3", modifiers: [.command, .option])
                .disabled(repository == nil)
            Button("Find Commits…") { repository?.beginSearch() }
                .keyboardShortcut("f")
                .disabled(repository == nil)
            Button("Show HEAD") {
                guard let repository else { return }
                Task { await repository.showHead() }
            }
            .disabled(repository == nil)
            Divider()
            Toggle("Hide Tags", isOn: binding(\.hidesTags))
                .disabled(repository == nil)
            Toggle("Hide Stashes", isOn: binding(\.hidesStashes))
                .disabled(repository == nil)
            Toggle("Show Lost Commits (Reflog)", isOn: binding(\.showsLostCommits))
                .disabled(repository == nil)
            Toggle("Collapse All Merges", isOn: binding(\.firstParentOnly))
                .disabled(repository == nil)
            Toggle("Filter Current Branch", isOn: binding(\.currentBranchOnly))
                .disabled(repository == nil)
            Divider()
        }
    }

    private func binding(_ option: WritableKeyPath<HistoryOptions, Bool>) -> Binding<Bool> {
        Binding(
            get: { repository?.historyOptions[keyPath: option] ?? false },
            set: { value in
                guard let repository else { return }
                Task { await repository.setHistoryOption(option, to: value) }
            }
        )
    }
}
