import MorkDomain
import SwiftUI

struct HistorySearchBar: View {
    @Bindable var viewModel: RepositoryViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.xs) {
            HStack(spacing: Metrics.Spacing.s) {
                Picker("Search By", selection: $viewModel.searchMode) {
                    ForEach(CommitSearchMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .fixedSize()
                .accessibilityIdentifier("search.mode")
                HStack(spacing: Metrics.Spacing.xs + Metrics.Spacing.xxs) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: Metrics.Control.fieldGlyph))
                        .foregroundStyle(Palette.Text.tertiary.color)
                    TextField(viewModel.searchMode.prompt, text: $viewModel.searchText, prompt: Text(viewModel.searchMode.prompt).foregroundStyle(Palette.Text.tertiary.color))
                    .textFieldStyle(.plain)
                    .font(Metrics.Font.body)
                    .foregroundStyle(Palette.Text.primary.color)
                    .focused($isFocused)
                    .onExitCommand { viewModel.clearSearch() }
                    .accessibilityIdentifier("search.field")
                    if viewModel.search.isSearching {
                        ProgressView()
                            .controlSize(.mini)
                    }
                    if viewModel.isSearchActive {
                        Button { viewModel.clearSearch() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: Metrics.Control.fieldGlyph))
                                .frame(width: Metrics.HitTarget.inline, height: Metrics.Control.searchField)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Palette.Text.tertiary.color)
                        .help("Clear Search")
                        .accessibilityLabel("Clear Search")
                        .accessibilityIdentifier("search.clear")
                    }
                }
                .padding(.leading, Metrics.Spacing.s)
                .frame(height: Metrics.Control.searchField)
                .fieldChrome(isFocused: isFocused)
                if let count = viewModel.search.matchCount {
                    Text(matchText(count))
                        .font(Metrics.Font.monoCaption)
                        .foregroundStyle(Palette.Text.secondary.color)
                        .accessibilityIdentifier("search.count")
                }
            }
            .frame(minHeight: Metrics.Control.regular)
            if let error = viewModel.search.error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(Metrics.Font.caption)
                    .foregroundStyle(Palette.Status.conflict.ink.color)
                    .accessibilityIdentifier("search.error")
            } else if viewModel.isSearchActive {
                Text(viewModel.searchMode.command(for: viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)))
                    .font(Metrics.Font.monoCaption)
                    .foregroundStyle(Palette.Text.secondary.color)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityIdentifier("search.command")
            }
        }
        .padding(.horizontal, Metrics.Spacing.s)
        .padding(.top, Metrics.Spacing.s)
        .padding(.bottom, Metrics.Spacing.xs + Metrics.Spacing.xxs)
        .background(Palette.Surface.window.color)
        .overlay(alignment: .bottom) { Hairline() }
        .onChange(of: viewModel.searchFocusRequest) { isFocused = true }
    }

    private func matchText(_ count: Int) -> String {
        if count >= RepositoryViewModel.historyLimit { return "\(count)+ matches" }
        return count == 1 ? "1 match" : "\(count) matches"
    }
}

struct BranchFilterBar: View {
    let branches: [String]
    let clear: () -> Void

    var body: some View {
        HStack(spacing: Metrics.Spacing.s) {
            Text("Filtered by: \(branches.map { "'\($0)'" }.joined(separator: ", "))")
                .foregroundStyle(Palette.Text.secondary.color)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(branches.joined(separator: ", "))
                .accessibilityIdentifier("history.branchFilter")
            Button("Clear filter", action: clear)
                .buttonStyle(.plain)
                .foregroundStyle(Palette.Accent.text.color)
                .frame(minHeight: Metrics.HitTarget.inline)
                .fixedSize()
                .help("Clear branch filters")
                .accessibilityLabel("Clear History Filter")
                .accessibilityIdentifier("history.branchFilter.clear")
            Spacer(minLength: 0)
        }
        .font(Metrics.Font.caption)
        .padding(.horizontal, Metrics.Spacing.s)
        .frame(minHeight: Metrics.Control.regular)
        .background(Palette.Surface.window.color)
        .overlay(alignment: .bottom) { Hairline() }
    }
}

struct HistorySearchEmptyState: View {
    let viewModel: RepositoryViewModel

    var body: some View {
        if viewModel.search.results?.isEmpty == true {
            EmptyStateView("No Results for “\(viewModel.searchText)”", systemImage: "magnifyingglass", message: "Check the spelling or try a new search.")
                .accessibilityIdentifier("search.noResults")
        }
    }
}

struct LostCommitBadge: View {
    var body: some View {
        Label("lost", systemImage: "arrow.uturn.backward")
            .labelStyle(.titleAndIcon)
            .font(Metrics.Font.caption)
            .lineLimit(1)
            .foregroundStyle(Palette.Status.renamed.ink.color)
            .padding(.horizontal, Metrics.Badge.padding)
            .frame(height: Metrics.Control.badge)
            .overlay(RoundedRectangle(cornerRadius: Metrics.Radius.small).strokeBorder(Palette.Status.renamed.ink.color, style: StrokeStyle(lineWidth: Metrics.Line.hairline, dash: Metrics.Line.dash)))
            .help("Not reachable from any branch or tag. Only git reflog still knows it: create a branch here to keep it.")
    }
}

extension CommitSearchMode {
    var title: String {
        switch self {
        case .message: "Message"
        case .author: "Author"
        case .hash: "Hash"
        case .content: "Content (-S)"
        case .regex: "Regex (-G)"
        }
    }

    var prompt: String {
        switch self {
        case .message: "Search commit messages"
        case .author: "Search author names"
        case .hash: "Commit hash prefix"
        case .content: "Text added or removed by a commit"
        case .regex: "Regular expression in changed lines"
        }
    }

    func command(for term: String) -> String {
        let quoted = ShellWords.quote(term)
        return switch self {
        case .message: "git log --all -i -F --grep=\(quoted)"
        case .author: "git log --all -i -F --author=\(quoted)"
        case .hash: "git rev-list --all, keep hashes starting with \(quoted)"
        case .content: "git log --all -S\(quoted)"
        case .regex: "git log --all -G\(quoted)"
        }
    }
}
