import SwiftUI

struct BranchNameCompletionInput: View {
    @Binding var name: String
    let branchNames: [String]
    let identifier: String
    let onSubmit: () -> Void
    @State private var selection: Int?
    @State private var suggestions: [BranchFolderSuggestion] = []
    @State private var isFocused = false

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Dropdown.gap) {
            BranchNameField(text: Binding(get: { name }, set: {
                name = $0
                selection = nil
                suggestions = BranchFolderSuggestion.suggestions(for: $0, branchNames: branchNames)
            }), onMove: { offset in
                guard !suggestions.isEmpty else { return false }
                selection = min(max((selection ?? (offset > 0 ? -1 : suggestions.count)) + offset, 0), suggestions.count - 1)
                return true
            }, onSubmit: {
                if let selection, suggestions.indices.contains(selection) {
                    accept(suggestions[selection].folder)
                } else {
                    onSubmit()
                }
            }, onDismiss: {
                guard !suggestions.isEmpty else { return false }
                suggestions = []
                selection = nil
                return true
            }, onFocus: { isFocused = $0 }, identifier: "\(identifier).name")
            .frame(height: Metrics.BranchName.fieldHeight)
            .padding(.horizontal, Metrics.Spacing.s)
            .frame(height: Metrics.Control.regular)
            .fieldChrome(isFocused: isFocused)

            if !suggestions.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(suggestions.enumerated()), id: \.element) { index, suggestion in
                                Button { accept(suggestion.folder) } label: {
                                    SuggestionRow(suggestion: suggestion, isSelected: selection == index)
                                }
                                .buttonStyle(.plain)
                                .id(index)
                                .accessibilityLabel(suggestion.folder)
                                .accessibilityIdentifier("\(identifier).suggestion.\(suggestion.folder)")
                            }
                        }
                    }
                    .frame(height: min(CGFloat(suggestions.count) * Metrics.BranchName.suggestionRow, Metrics.BranchName.suggestionsMaximumHeight))
                    .background(Palette.Surface.window.color)
                    .clipShape(RoundedRectangle(cornerRadius: Metrics.Dropdown.radius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Metrics.Dropdown.radius, style: .continuous).strokeBorder(Palette.Surface.border.color, lineWidth: Metrics.Line.hairline))
                    .modifier(PopoverShadow())
                    .onChange(of: selection) { _, index in
                        if let index { proxy.scrollTo(index) }
                    }
                }
            }
        }
        .onAppear { suggestions = BranchFolderSuggestion.suggestions(for: name, branchNames: branchNames) }
    }

    private func accept(_ folder: String) {
        name = folder
        selection = nil
        suggestions = []
    }
}

private struct SuggestionRow: View {
    let suggestion: BranchFolderSuggestion
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Metrics.Spacing.s) {
            Image(systemName: "folder")
                .font(.system(size: Metrics.Icon.small))
                .foregroundStyle(Palette.Text.secondary.color)
                .frame(width: Metrics.Icon.column)
            (Text(suggestion.matched).fontWeight(.semibold) + Text(suggestion.rest))
                .font(Metrics.Font.title)
                .foregroundStyle(Palette.Text.primary.color)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: Metrics.Spacing.s)
            Text(suggestion.countTitle)
                .font(Metrics.Font.caption)
                .foregroundStyle(Palette.Text.secondary.color)
        }
        .padding(.horizontal, Metrics.Sheet.commandStripInset)
        .frame(maxWidth: .infinity, minHeight: Metrics.BranchName.suggestionRow, maxHeight: Metrics.BranchName.suggestionRow, alignment: .leading)
        .background(isSelected ? Palette.Accent.tint.color : isHovered ? Palette.Text.primary.color.opacity(Palette.Ink.hover) : .clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}
