import MorkDomain
import SwiftUI

struct LessonBrowserView: View {
    @Bindable var viewModel: LessonBrowserViewModel

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: Metrics.Spacing.s) {
                SearchField(prompt: "Search lessons", text: $viewModel.query, identifier: "lessons.search")
                LessonTopicList(viewModel: viewModel)
            }
            .frame(width: Metrics.Lesson.listWidth)
            .padding(Metrics.Spacing.m)
            Hairline(isVertical: true)
            if let topic = viewModel.selected {
                LessonDetail(topic: topic)
                    .id(topic.id)
            } else {
                EmptyStateView("No Lessons", systemImage: "magnifyingglass", message: "No command, summary or flag matches your search.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("lessons.empty")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lessons")
    }
}

private struct LessonTopicList: View {
    let viewModel: LessonBrowserViewModel

    var body: some View {
        let selectedID = viewModel.selectedID
        let firstID = viewModel.topics.first?.id
        ScrollViewReader { proxy in
            List(selection: Binding(get: { viewModel.selectedID }, set: { viewModel.selectedID = $0 })) {
                ForEach(viewModel.topics) { topic in
                    LessonTopicRow(topic: topic)
                        .frame(height: Metrics.Row.twoLine)
                        .background { if topic.id == selectedID || topic.id == firstID { InkSelectionTableStyle() } }
                        .listRowBackground(topic.id == selectedID ? Palette.Accent.tint.color : nil)
                        .listRowInsets(Metrics.listRowInsets)
                        .listRowSeparator(.hidden)
                        .tag(topic.id)
                }
            }
            .listStyle(.bordered)
            .environment(\.defaultMinListRowHeight, Metrics.Row.twoLine)
            .accessibilityIdentifier("lessons.list")
            .onAppear { proxy.scrollTo(selectedID, anchor: .center) }
        }
    }
}

private struct LessonTopicRow: View {
    let topic: LessonTopic

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(topic.command)
                .font(Metrics.Font.monoBody)
                .foregroundStyle(Palette.Text.primary.color)
                .lineLimit(1)
            Text(topic.summary)
                .font(Metrics.Font.body)
                .foregroundStyle(Palette.Text.secondary.color)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("lessons.row.\(topic.command)")
    }
}

private struct LessonDetail: View {
    let topic: LessonTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.Spacing.l) {
                Text("git \(topic.command)")
                    .font(Metrics.Font.heading.monospaced())
                    .foregroundStyle(Palette.Text.primary.color)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("lessons.detail.command")
                Text(topic.explanation)
                    .font(Metrics.Font.title)
                    .foregroundStyle(Palette.Text.primary.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("lessons.detail.explanation")
                if !topic.actions.isEmpty {
                    LessonNoteTable(title: "ACTIONS", notes: topic.actions)
                }
                if !topic.flags.isEmpty {
                    LessonNoteTable(title: "FLAGS", notes: topic.flags)
                }
            }
            .padding(Metrics.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lessons.detail")
    }
}

private struct LessonNoteTable: View {
    let title: String
    let notes: [LessonNote]

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.s) {
            Text(title)
                .font(Metrics.Font.label)
                .tracking(Metrics.Font.labelTracking)
                .foregroundStyle(Palette.Text.secondary.color)
            Grid(alignment: .topLeading, horizontalSpacing: Metrics.Spacing.m, verticalSpacing: Metrics.Spacing.s) {
                ForEach(notes) { note in
                    GridRow {
                        Text(note.name)
                            .font(Metrics.Font.monoBody)
                            .foregroundStyle(Palette.Text.primary.color)
                            .frame(width: Metrics.Lesson.flagColumnWidth, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(note.text)
                            .font(Metrics.Font.body)
                            .foregroundStyle(Palette.Text.secondary.color)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .textSelection(.enabled)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("lessons.note.\(note.name)")
                }
            }
        }
    }
}
