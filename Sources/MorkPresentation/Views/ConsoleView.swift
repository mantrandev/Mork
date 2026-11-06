import AppKit
import MorkDomain
import SwiftUI

struct ConsoleView: View {
    @Bindable var console: ConsoleViewModel
    let onRun: (String) -> Void
    @State private var input = ""

    var body: some View {
        VStack(spacing: 0) {
            ConsoleRecordList(console: console)
                .overlay {
                    if !console.hasVisibleRecords {
                        Text("Git commands Mork runs will appear here. Type your own below.")
                            .font(Metrics.Font.body)
                            .foregroundStyle(Palette.Text.secondary.color)
                            .multilineTextAlignment(.center)
                            .padding(Metrics.Spacing.l)
                            .accessibilityIdentifier("console.empty")
                    }
                }
            Divider()
            HStack(spacing: Metrics.Spacing.s) {
                Color.clear
                    .frame(width: Metrics.Icon.column, height: 1)
                Text("$")
                    .font(Metrics.Font.monoBody)
                    .foregroundStyle(Palette.Text.tertiary.color)
                TextField("git log --oneline -5", text: $input)
                    .textFieldStyle(.plain)
                    .font(Metrics.Font.monoBody)
                    .foregroundStyle(Palette.Text.primary.color)
                    .onSubmit(run)
                    .accessibilityIdentifier("console.input")
                Button(action: run) {
                    HStack(spacing: Metrics.Spacing.xs) {
                        Text("Run")
                        Text("⏎")
                            .foregroundStyle(Palette.Text.secondary.color)
                    }
                }
                .buttonStyle(.mork(.secondary, size: .small))
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Run")
                .accessibilityIdentifier("console.run")
            }
            .padding(.horizontal, Metrics.Spacing.m)
            .frame(height: Metrics.Panel.consoleInputRow)
        }
    }

    private func run() {
        let command = input.trimmingCharacters(in: .whitespaces)
        guard !command.isEmpty else { return }
        input = ""
        onRun(command)
    }
}

private struct ConsoleRecordList: View {
    let console: ConsoleViewModel

    var body: some View {
        ConsoleTable(records: console.visibleRecords, showsLessons: console.showsLessons, lesson: console.explanation(for:))
    }
}

struct RecordRow: View {
    let record: GitCommandRecord
    let lesson: String?
    let isExpanded: Binding<Bool>

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.Spacing.s) {
            ConsoleStatusGlyph(succeeded: record.succeeded)
            VStack(alignment: .leading, spacing: Metrics.Spacing.xs) {
                (Text("$ ").foregroundStyle(Palette.Text.tertiary.color) + Text(record.commandLine).foregroundStyle(Palette.Text.primary.color))
                    .font(Metrics.Font.monoBody)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("console.command")
                ForEach(record.notes, id: \.self) { note in
                    Label(note, systemImage: "person.badge.key")
                        .font(Metrics.Font.body)
                        .foregroundStyle(Palette.Text.secondary.color)
                        .accessibilityIdentifier("console.note")
                }
                if let lesson {
                    Text(ConsoleLesson.cached(lesson))
                        .font(Metrics.Font.body)
                        .foregroundStyle(Palette.Text.secondary.color)
                        .accessibilityIdentifier("console.lesson")
                }
                let output = ConsoleOutput.format(record)
                if !output.isEmpty {
                    if record.succeeded {
                        DisclosureGroup("Output (\(record.exitSummary))", isExpanded: isExpanded) {
                            Text(output)
                                .font(Metrics.Font.monoCaption)
                                .foregroundStyle(Palette.Text.secondary.color)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(Metrics.Font.caption)
                        .foregroundStyle(Palette.Text.secondary.color)
                    } else {
                        Text(output)
                            .font(Metrics.Font.monoBody)
                            .foregroundStyle(Palette.Status.deleted.ink.color)
                            .textSelection(.enabled)
                            .padding(.vertical, Metrics.Spacing.xs)
                            .padding(.horizontal, Metrics.Spacing.s)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.Status.deleted.tint.color, in: RoundedRectangle(cornerRadius: Metrics.Radius.small, style: .continuous))
                            .accessibilityIdentifier("console.error")
                    }
                }
            }
            Spacer(minLength: Metrics.Spacing.s)
            HStack(spacing: Metrics.Spacing.s) {
                Text(record.exitSummary)
                    .foregroundStyle(Self.exitInk(for: record).color)
                Text(String(format: "%.0f ms", record.duration * 1000))
                    .foregroundStyle(Palette.Text.secondary.color)
                PanelIconButton(title: "Copy", systemImage: "doc.on.doc", help: "Copy the command", identifier: "console.copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(record.commandLine, forType: .string)
                }
            }
            .font(Metrics.Font.monoCaption)
            .frame(height: Metrics.LineHeight.body)
        }
    }

    static func exitInk(for record: GitCommandRecord) -> ColorToken {
        if record.conflictCount != nil { return Palette.Status.added.ink }
        return record.succeeded ? Palette.Text.secondary : Palette.Status.deleted.ink
    }
}

private struct ConsoleStatusGlyph: View {
    let succeeded: Bool

    var body: some View {
        let status = succeeded ? Palette.Status.added : Palette.Status.deleted
        Image(systemName: succeeded ? "checkmark" : "xmark")
            .font(Metrics.Font.label.weight(.heavy))
            .foregroundStyle(status.ink.color)
            .frame(width: Metrics.Icon.column, height: Metrics.Icon.column)
            .background(status.tint.color, in: Circle())
            .accessibilityLabel(succeeded ? "Succeeded" : "Failed")
    }
}

@MainActor
enum ConsoleLesson {
    static let cacheLimit = 256
    private static var cache: [String: AttributedString] = [:]
    private static let flag = try? NSRegularExpression(pattern: "(?<![\\w-])--?[A-Za-z][A-Za-z0-9-]*(?:=[^\\s:,]*)?")

    static func cached(_ lesson: String) -> AttributedString {
        if let styled = cache[lesson] { return styled }
        if cache.count >= cacheLimit { cache.removeAll(keepingCapacity: true) }
        let styled = styled(lesson)
        cache[lesson] = styled
        return styled
    }

    static func styled(_ lesson: String) -> AttributedString {
        var result = AttributedString(lesson)
        for range in flagRanges(in: lesson) {
            guard let target = Range(NSRange(range, in: lesson), in: result) else { continue }
            result[target].font = Metrics.Font.monoBody
            result[target].foregroundColor = Palette.Text.primary.color
        }
        return result
    }

    static func flagRanges(in lesson: String) -> [Range<String.Index>] {
        guard let flag else { return [] }
        return flag.matches(in: lesson, range: NSRange(lesson.startIndex..., in: lesson)).compactMap { Range($0.range, in: lesson) }
    }
}

enum ConsoleOutput {
    static let maxCharacters = 4000

    static func format(_ record: GitCommandRecord) -> String {
        let combined = [record.stdout, record.stderr]
            .map { $0.replacingOccurrences(of: "\0", with: "␀").replacingOccurrences(of: "\u{1f}", with: "␟") }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        return combined.count > maxCharacters ? String(combined.prefix(maxCharacters)) + "\n…" : combined
    }
}
