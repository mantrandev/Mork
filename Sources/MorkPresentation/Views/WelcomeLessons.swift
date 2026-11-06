import MorkDomain
import SwiftUI

struct LessonBrowserSheet: View {
    let viewModel: LessonBrowserViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        DialogScaffold(kind: .notice, glyph: "graduationcap", title: "Git Lessons", message: "What each git command does, and what its flags mean. The Git Console shows the same lesson under every command Mork runs.", width: Metrics.Sheet.largeWidth) {
            LessonBrowserView(viewModel: viewModel)
                .frame(height: Metrics.Lesson.sheetBrowserHeight)
                .overlay(RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous).strokeBorder(Palette.Surface.border.color, lineWidth: Metrics.Line.hairline))
        } buttons: {
            DialogCancelButton(title: "Close") { dismiss() }
        }
        .accessibilityIdentifier("lessonBrowserSheet")
    }
}

struct WelcomeLessons: View {
    let topics: [LessonTopic]
    let onOpen: (String) -> Void

    var body: some View {
        VStack(spacing: Metrics.Spacing.s) {
            Text("LEARN GIT")
                .font(Metrics.Font.label)
                .tracking(Metrics.Font.labelTracking)
                .foregroundStyle(Palette.Text.secondary.color)
            HStack(alignment: .top, spacing: Metrics.Spacing.s) {
                ForEach(topics) { topic in
                    LessonCard(topic: topic) { onOpen(topic.command) }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("welcome.lessons")
    }
}

private struct LessonCard: View {
    let topic: LessonTopic
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.Radius.card, style: .continuous)
        Button(action: action) {
            VStack(alignment: .leading, spacing: Metrics.Spacing.xs) {
                Text("git \(topic.command)")
                    .font(Metrics.Font.monoBody)
                    .foregroundStyle(Palette.Accent.text.color)
                Text(topic.summary)
                    .font(Metrics.Font.body)
                    .foregroundStyle(Palette.Text.secondary.color)
                    .multilineTextAlignment(.leading)
                    .lineLimit(5)
                Spacer(minLength: 0)
            }
            .padding(Metrics.Spacing.m)
            .frame(width: Metrics.Lesson.cardWidth, height: Metrics.Lesson.cardHeight, alignment: .topLeading)
            .background(Palette.Surface.raised.color, in: shape)
            .overlay(shape.fill(Palette.Text.primary.color.opacity(isHovered ? Palette.Ink.hover : 0)))
            .overlay(shape.strokeBorder(Palette.Surface.border.color, lineWidth: Metrics.Line.hairline))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Open the lesson for git \(topic.command)")
        .accessibilityLabel("git \(topic.command)")
        .accessibilityHint(topic.summary)
        .accessibilityIdentifier("welcome.lesson.\(topic.command)")
    }
}
