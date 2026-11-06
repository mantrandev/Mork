import MorkDomain
import SwiftUI

struct QuickLaunchPalette: View {
    let app: AppViewModel
    @Bindable var quickLaunch: QuickLaunchViewModel
    let onChooseFolder: (QuickLaunchCommand) -> Void
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                PopoverShadow.ink.opacity(Palette.Ink.selection)
                    .ignoresSafeArea(.container, edges: .top)
                    .contentShape(Rectangle())
                    .onTapGesture { app.dismissQuickLaunch() }
                    .accessibilityHidden(true)
                VStack(spacing: 0) {
                    field
                    Hairline()
                    if quickLaunch.results.isEmpty {
                        Text("No matches")
                            .font(Metrics.Font.title)
                            .foregroundStyle(Palette.Text.secondary.color)
                            .frame(maxWidth: .infinity)
                            .padding(Metrics.Spacing.l)
                            .accessibilityIdentifier("quickLaunch.empty")
                    } else {
                        results(height: Metrics.QuickLaunch.listHeight(windowHeight: geometry.size.height, resultCount: quickLaunch.results.count))
                    }
                }
                .frame(width: Metrics.Sheet.wideWidth)
                .background(Palette.Surface.raised.color, in: RoundedRectangle(cornerRadius: Metrics.Radius.popover, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Metrics.Radius.popover, style: .continuous).strokeBorder(Palette.Surface.border.color, lineWidth: Metrics.Line.hairline))
                .modifier(PopoverShadow())
                .padding(.top, Metrics.QuickLaunch.topInset)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("quickLaunch")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .task {
            for _ in 0..<20 where !isFieldFocused {
                isFieldFocused = true
                try? await Task.sleep(for: .milliseconds(25))
            }
        }
    }

    private var field: some View {
        HStack(spacing: Metrics.Spacing.s) {
            Image(systemName: "magnifyingglass")
                .font(Metrics.Font.heading.weight(.regular))
                .foregroundStyle(Palette.Text.tertiary.color)
            TextField("Jump to a tab, repository, branch, tag or command", text: $quickLaunch.query, prompt: Text("Jump to a tab, repository, branch, tag or command").foregroundStyle(Palette.Text.tertiary.color))
                .textFieldStyle(.plain)
                .font(Metrics.Font.heading.weight(.regular))
                .foregroundStyle(Palette.Text.primary.color)
                .focused($isFieldFocused)
                .onSubmit(run)
                .onKeyPress(.upArrow) {
                    quickLaunch.moveSelection(by: -1)
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    quickLaunch.moveSelection(by: 1)
                    return .handled
                }
                .onKeyPress(.escape) {
                    app.dismissQuickLaunch()
                    return .handled
                }
                .onExitCommand { app.dismissQuickLaunch() }
                .accessibilityIdentifier("quickLaunch.field")
        }
        .frame(height: Metrics.QuickLaunch.fieldHeight)
        .padding(Metrics.Spacing.m)
    }

    private func results(height: CGFloat) -> some View {
        ScrollViewReader { proxy in
            List(quickLaunch.results) { result in
                QuickLaunchRow(result: result, isSelected: result.id == quickLaunch.selectedID)
                    .id(result.id)
                    .onTapGesture {
                        quickLaunch.select(result)
                        run()
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: Metrics.Spacing.xs + Metrics.Spacing.xxs, bottom: 0, trailing: Metrics.Spacing.xs + Metrics.Spacing.xxs))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.vertical, 0, for: .scrollContent)
            .environment(\.defaultMinListRowHeight, Metrics.QuickLaunch.rowHeight)
            .frame(height: height)
            .accessibilityIdentifier("quickLaunch.results")
            .onChange(of: quickLaunch.selectedIndex) { _, index in
                guard quickLaunch.results.indices.contains(index) else { return }
                proxy.scrollTo(quickLaunch.results[index].id)
            }
        }
    }

    private func run() {
        guard let item = quickLaunch.selectedItem else { return }
        if case let .command(command) = item.kind, command.choosesFolder {
            app.dismissQuickLaunch()
            onChooseFolder(command)
            return
        }
        Task { await app.runQuickLaunch(item) }
    }
}

private struct QuickLaunchRow: View {
    let result: QuickLaunchResult
    let isSelected: Bool

    var body: some View {
        HStack(spacing: Metrics.Spacing.s + Metrics.Spacing.xxs) {
            Image(systemName: systemImage)
                .font(.system(size: Metrics.Icon.regular))
                .frame(width: Metrics.Icon.column + Metrics.Spacing.xxs)
                .foregroundStyle(isSelected ? Palette.Accent.text.color : Palette.Text.secondary.color)
            VStack(alignment: .leading, spacing: 0) {
                Text(QuickLaunchHighlight.attributed(result.item.title, ranges: result.highlights))
                    .font(Metrics.Font.title.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Palette.Accent.text.color : Palette.Text.primary.color)
                    .lineLimit(1)
                Text(result.item.subtitle)
                    .font(Metrics.Font.caption)
                    .foregroundStyle(Palette.Text.secondary.color)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.Spacing.s)
        .frame(height: Metrics.QuickLaunch.rowHeight)
        .background(isSelected ? Palette.Accent.tint.color : Color.clear, in: RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(isSelected ? "selected" : "")
        .accessibilityIdentifier("quickLaunch.row.\(result.id)")
    }

    private var systemImage: String {
        switch result.item.kind {
        case .tab: "rectangle.stack"
        case .recent: "clock"
        case .repository: "externaldrive"
        case let .branch(branch): branch.isRemote ? "cloud" : "arrow.triangle.branch"
        case .tag: "tag"
        case .command: "command"
        case .customCommand: "terminal"
        }
    }
}

enum QuickLaunchHighlight {
    struct Segment: Equatable {
        let text: String
        let isMatch: Bool
    }

    static func segments(_ title: String, ranges: [Range<Int>]) -> [Segment] {
        var segments: [Segment] = []
        var current = String.UnicodeScalarView()
        var currentIsMatch = false
        for (offset, scalar) in title.unicodeScalars.enumerated() {
            let isMatch = ranges.contains { $0.contains(offset) }
            if isMatch != currentIsMatch, !current.isEmpty {
                segments.append(Segment(text: String(current), isMatch: currentIsMatch))
                current = String.UnicodeScalarView()
            }
            currentIsMatch = isMatch
            current.append(scalar)
        }
        if !current.isEmpty { segments.append(Segment(text: String(current), isMatch: currentIsMatch)) }
        return segments
    }

    static func attributed(_ title: String, ranges: [Range<Int>]) -> AttributedString {
        segments(title, ranges: ranges).reduce(into: AttributedString()) { result, segment in
            var part = AttributedString(segment.text)
            if segment.isMatch {
                part.font = Metrics.Font.title.bold()
                part.underlineStyle = .single
            }
            result += part
        }
    }
}
