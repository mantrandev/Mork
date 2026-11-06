import MorkDomain
import SwiftUI

struct IgnoreMenu: View {
    let viewModel: RepositoryViewModel
    let change: FileChange

    var body: some View {
        if change.isUntracked {
            let suggestions = viewModel.ignoreSuggestions(for: change)
            Menu("Ignore") { items(for: .gitignore, suggestions: suggestions) }
                .accessibilityIdentifier("ignore.menu.\(change.path)")
            Menu("Exclude Locally") { items(for: .exclude, suggestions: suggestions) }
                .accessibilityIdentifier("exclude.menu.\(change.path)")
        }
    }

    @ViewBuilder
    private func items(for target: IgnoreTarget, suggestions: [IgnoreSuggestion]) -> some View {
        ForEach(suggestions, id: \.self) { suggestion in
            Button(Self.title(of: suggestion)) {
                Task { await viewModel.ignore(change, rule: suggestion.pattern, target: target) }
            }
            .accessibilityIdentifier("\(target.rawValue).\(Self.identifier(of: suggestion.kind))")
        }
        if !suggestions.isEmpty { Divider() }
        Button("Custom Pattern…") { viewModel.beginCustomIgnore(change, target: target) }
            .accessibilityIdentifier("\(target.rawValue).custom")
    }

    static func title(of suggestion: IgnoreSuggestion) -> String {
        switch suggestion.kind {
        case .file: "This File  \(suggestion.pattern)"
        case .fileExtension: "All Files Like \(suggestion.pattern)"
        case .folder: "This Folder  \(suggestion.pattern)"
        }
    }

    private static func identifier(of kind: IgnoreSuggestion.Kind) -> String {
        switch kind {
        case .file: "file"
        case .fileExtension: "extension"
        case .folder: "folder"
        }
    }
}

struct IgnoreRuleSheet: View {
    let viewModel: RepositoryViewModel
    @State var draft: IgnoreDraft
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        DialogScaffold(
            kind: .form,
            glyph: "eye.slash",
            title: "Add Ignore Rule",
            message: draft.path
        ) {
            VStack(alignment: .leading, spacing: Metrics.Sheet.rowSpacing) {
                DialogLabeledRow("Pattern") {
                    DialogTextField(placeholder: "Pattern, for example *.log or /build/", text: $draft.rule, identifier: "ignoreSheet.pattern", isMonospaced: true, onSubmit: confirm)
                }
                DialogLabeledRow("Write to") {
                    VStack(alignment: .leading, spacing: Metrics.Spacing.xs) {
                        Picker("Write to", selection: $draft.target) {
                            ForEach(IgnoreTarget.allCases) { target in
                                Text(target.fileName).font(Metrics.Font.monoBody).tag(target)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                        .accessibilityIdentifier("ignoreSheet.target")
                        DialogNote(text: draft.target.lesson)
                    }
                }
            }
        } buttons: {
            DialogCancelButton { dismiss() }
            DialogConfirmButton(title: "Add Rule", identifier: "ignoreSheet.confirm", action: confirm)
                .disabled(GitIgnorePattern.custom(draft.rule) == nil)
        }
    }

    private func confirm() {
        guard GitIgnorePattern.custom(draft.rule) != nil else { return }
        let draft = draft
        dismiss()
        Task { await viewModel.ignore(path: draft.path, rule: draft.rule, target: draft.target) }
    }
}
