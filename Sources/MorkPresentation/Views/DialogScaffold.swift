import SwiftUI

extension Palette.Surface {
    static let dialog = ColorToken(light: 0xFFFFFF, dark: 0x262829)
    static let well = ColorToken(light: 0xF3F4F4, dark: 0x1C1D1E)
}

enum DialogKind: CaseIterable, Equatable {
    case destructive
    case notice
    case form
    case options
    case error
    case warning

    var width: CGFloat {
        switch self {
        case .destructive, .notice, .warning: Metrics.Sheet.alertWidth
        case .form, .error: Metrics.Sheet.width
        case .options: Metrics.Sheet.dialogWidth
        }
    }

    var tile: ColorToken {
        switch self {
        case .destructive, .error: Palette.Status.deleted.tint
        case .warning: Palette.Status.conflict.tint
        case .notice, .form, .options: Palette.Accent.tint
        }
    }

    var ink: ColorToken {
        switch self {
        case .destructive, .error: Palette.Status.deleted.ink
        case .warning: Palette.Status.conflict.ink
        case .notice, .form, .options: Palette.Accent.text
        }
    }

    var glyph: String {
        switch self {
        case .destructive: "trash"
        case .notice: "checkmark"
        case .form: "plus"
        case .options: "slider.horizontal.3"
        case .error: "xmark"
        case .warning: "exclamationmark.triangle"
        }
    }
}

struct DialogGlyphTile: View {
    let kind: DialogKind
    var glyph: String?

    var body: some View {
        Image(systemName: glyph ?? kind.glyph)
            .font(.system(size: Metrics.Sheet.dialogGlyphSize, weight: .medium))
            .foregroundStyle(kind.ink.color)
            .frame(width: Metrics.Sheet.dialogIconSize, height: Metrics.Sheet.dialogIconSize)
            .background(kind.tile.color, in: RoundedRectangle(cornerRadius: Metrics.Radius.popover, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct DialogHeader: View {
    let kind: DialogKind
    var glyph: String?
    let title: String
    var message: String?
    var titleIdentifier: String?
    var messageIdentifier: String?

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.Sheet.headerGap) {
            DialogGlyphTile(kind: kind, glyph: glyph)
            VStack(alignment: .leading, spacing: Metrics.Spacing.xs) {
                Text(title)
                    .font(Metrics.Font.heading)
                    .foregroundStyle(Palette.Text.primary.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .optionalIdentifier(titleIdentifier)
                if let message, !message.isEmpty {
                    Text(message)
                        .font(Metrics.Font.title)
                        .foregroundStyle(Palette.Text.secondary.color)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .optionalIdentifier(messageIdentifier)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct DialogScaffold<Content: View, Leading: View, Buttons: View>: View {
    let kind: DialogKind
    var glyph: String?
    let title: String
    var message: String?
    var width: CGFloat?
    var titleIdentifier: String?
    var messageIdentifier: String?
    @ViewBuilder var content: Content
    @ViewBuilder var leading: Leading
    @ViewBuilder var buttons: Buttons

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Sheet.sectionSpacing) {
            DialogHeader(kind: kind, glyph: glyph, title: title, message: message, titleIdentifier: titleIdentifier, messageIdentifier: messageIdentifier)
            content
            DialogButtonRow { leading } trailing: { buttons }
        }
        .padding(Metrics.Sheet.padding)
        .frame(width: width ?? kind.width, alignment: .leading)
        .dialogSurface()
    }
}

extension DialogScaffold where Leading == EmptyView {
    init(kind: DialogKind, glyph: String? = nil, title: String, message: String? = nil, width: CGFloat? = nil, titleIdentifier: String? = nil, messageIdentifier: String? = nil, @ViewBuilder content: () -> Content, @ViewBuilder buttons: () -> Buttons) {
        self.init(kind: kind, glyph: glyph, title: title, message: message, width: width, titleIdentifier: titleIdentifier, messageIdentifier: messageIdentifier, content: content, leading: { EmptyView() }, buttons: buttons)
    }
}

extension DialogScaffold where Content == EmptyView, Leading == EmptyView {
    init(kind: DialogKind, glyph: String? = nil, title: String, message: String? = nil, width: CGFloat? = nil, titleIdentifier: String? = nil, messageIdentifier: String? = nil, @ViewBuilder buttons: () -> Buttons) {
        self.init(kind: kind, glyph: glyph, title: title, message: message, width: width, titleIdentifier: titleIdentifier, messageIdentifier: messageIdentifier, content: { EmptyView() }, leading: { EmptyView() }, buttons: buttons)
    }
}

struct DialogButtonRow<Leading: View, Trailing: View>: View {
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Metrics.Spacing.s) {
            leading
            Spacer(minLength: Metrics.Spacing.s)
            trailing
        }
    }
}

extension DialogButtonRow where Leading == EmptyView {
    init(@ViewBuilder trailing: () -> Trailing) {
        self.init(leading: { EmptyView() }, trailing: trailing)
    }
}

struct DialogDefaultLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: Metrics.Spacing.s) {
            Text(title)
                .fontWeight(.semibold)
            Text("↩")
                .font(Metrics.Font.monoCaption)
                .opacity(Metrics.Opacity.hint)
                .accessibilityHidden(true)
        }
    }
}

struct DialogConfirmButton: View {
    let title: String
    var isDestructive = false
    var isDefault = true
    var identifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isDefault {
                DialogDefaultLabel(title: title)
            } else {
                Text(title).fontWeight(.semibold)
            }
        }
        .buttonStyle(MorkButtonStyle(kind: isDestructive ? .destructiveConfirm : .primary))
        .keyboardShortcut(isDefault ? .defaultAction : nil)
        .accessibilityLabel(title)
        .optionalIdentifier(identifier)
    }
}

struct DialogCancelButton: View {
    var title = "Cancel"
    var identifier: String?
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.morkSecondary)
            .keyboardShortcut(.cancelAction)
            .optionalIdentifier(identifier)
    }
}

struct DialogLabeledRow<Content: View>: View {
    let label: String?
    @ViewBuilder let content: Content

    init(_ label: String?, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.Sheet.labelGap) {
            Text(label ?? "")
                .font(Metrics.Font.title)
                .foregroundStyle(Palette.Text.secondary.color)
                .lineLimit(1)
                .frame(width: Metrics.Sheet.dialogLabelWidth, alignment: .trailing)
                .accessibilityHidden(label == nil)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct DialogTextField: View {
    let placeholder: String
    @Binding var text: String
    var prompt: String?
    var identifier: String?
    var isMonospaced = false
    var onSubmit: () -> Void = {}
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $text, prompt: Text(prompt ?? placeholder).foregroundStyle(Palette.Text.tertiary.color))
            .textFieldStyle(.plain)
            .font(isMonospaced ? Metrics.Font.monoBody : Metrics.Font.title)
            .foregroundStyle(Palette.Text.primary.color)
            .focused($isFocused)
            .onSubmit(onSubmit)
            .optionalIdentifier(identifier)
            .padding(.horizontal, Metrics.Spacing.s)
            .frame(height: Metrics.Control.regular)
            .fieldChrome(isFocused: isFocused)
    }
}

struct DialogTextEditor: View {
    let placeholder: String
    @Binding var text: String
    var height: CGFloat = Metrics.Composer.descriptionHeight
    var identifier: String?
    var isMonospaced = false
    @FocusState private var isFocused: Bool

    var body: some View {
        TextEditor(text: $text)
            .font(isMonospaced ? Metrics.Font.monoBody : Metrics.Font.title)
            .foregroundStyle(Palette.Text.primary.color)
            .scrollContentBackground(.hidden)
            .focused($isFocused)
            .padding(.horizontal, Metrics.Spacing.xs)
            .padding(.vertical, Metrics.Spacing.xs + Metrics.Spacing.xxs)
            .frame(height: height)
            .fieldChrome(isFocused: isFocused)
            .optionalIdentifier(identifier)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(Metrics.Font.title)
                        .foregroundStyle(Palette.Text.tertiary.color)
                        .padding(.leading, Metrics.Spacing.s + Metrics.Line.hairline)
                        .padding(.top, Metrics.Spacing.xs + Metrics.Spacing.xxs)
                        .allowsHitTesting(false)
                }
            }
    }
}

struct DialogOptionToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title).fontWeight(.medium).foregroundStyle(Palette.Text.primary.color)
                .font(Metrics.Font.title)
                .fixedSize(horizontal: false, vertical: true)
        }
        .toggleStyle(.checkbox)
        .accessibilityLabel(title)
    }
}

struct DialogNote: View {
    let text: String
    var tone: Tone = .secondary

    enum Tone {
        case secondary
        case warning
        case danger
    }

    var body: some View {
        Group {
            if tone == .secondary {
                Text(text)
            } else {
                Label(text, systemImage: "exclamationmark.triangle")
            }
        }
        .font(Metrics.Font.body)
        .foregroundStyle(tone.color)
        .fixedSize(horizontal: false, vertical: true)
    }
}

extension DialogNote.Tone {
    var color: Color {
        switch self {
        case .secondary: Palette.Text.secondary.color
        case .warning: Palette.Status.conflict.ink.color
        case .danger: Palette.Status.deleted.ink.color
        }
    }
}

struct CommandStrip: View {
    let command: String
    var note: String?
    var identifier: String?
    var noteIdentifier: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.Spacing.s) {
            Text("$")
                .foregroundStyle(Palette.Text.tertiary.color)
                .accessibilityHidden(true)
            Text(command)
                .foregroundStyle(Palette.Text.primary.color)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .optionalIdentifier(identifier)
            if let note {
                Text(note)
                    .font(Metrics.Font.caption.monospacedDigit())
                    .foregroundStyle(Palette.Text.secondary.color)
                    .lineLimit(1)
                    .fixedSize()
                    .optionalIdentifier(noteIdentifier)
            }
        }
        .font(Metrics.Font.monoBody)
        .padding(.horizontal, Metrics.Sheet.commandStripInset)
        .padding(.vertical, Metrics.Spacing.xs)
        .frame(minHeight: Metrics.Sheet.commandStripHeight)
        .background(Palette.Surface.well.color, in: RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous))
        .textSelection(.enabled)
    }
}

struct CommandOutputBox: View {
    let command: String?
    let lines: [ErrorReport.Line]

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.xxs) {
            if let command {
                (Text("$ ").foregroundStyle(Palette.Text.tertiary.color) + Text(command).foregroundStyle(Palette.Text.primary.color))
            }
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line.text)
                    .foregroundStyle(line.isError ? Palette.Status.deleted.ink.color : Palette.Text.secondary.color)
            }
        }
        .font(Metrics.Font.monoBody)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Metrics.Spacing.s)
        .padding(.horizontal, Metrics.Sheet.commandStripInset)
        .textSelection(.enabled)
    }
}

struct DialogProgressBar: View {
    let fraction: Double?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.Status.untracked.tint.color)
                Capsule()
                    .fill(Palette.Accent.fill.color)
                    .frame(width: proxy.size.width * min(max(fraction ?? 1, 0), 1))
                    .opacity(fraction == nil ? Metrics.Opacity.dimmed : 1)
            }
        }
        .frame(height: Metrics.Sheet.progressHeight)
        .accessibilityElement()
        .accessibilityValue(fraction.map { "\(Int($0 * 100)) %" } ?? "in progress")
    }
}

struct DialogAction {
    var title: String
    var isDestructive = false
    var isDefault = false
    var command: String?
    var identifier: String?
    let perform: () -> Void
}

struct DialogCommandLine: Equatable {
    static let confirmNote = "runs on confirm"

    var text: String
    var note: String? = DialogCommandLine.confirmNote
    var identifier: String?
}

struct MorkConfirmation {
    var kind: DialogKind
    var glyph: String?
    var title: String
    var message: String? = nil
    var commands: [DialogCommandLine] = []
    var actions: [DialogAction]
    var cancelTitle: String? = "Cancel"
    var cancelIdentifier: String?
    var cancelAction: () -> Void = {}

    static func notice(title: String, message: String, glyph: String? = nil, identifier: String) -> MorkConfirmation {
        MorkConfirmation(kind: .notice, glyph: glyph, title: title, message: message, actions: [
            DialogAction(title: "OK", isDefault: true, identifier: identifier) {}
        ], cancelTitle: nil)
    }
}

struct MorkConfirmationView: View {
    let confirmation: MorkConfirmation
    let onFinish: () -> Void

    var body: some View {
        DialogScaffold(kind: confirmation.kind, glyph: confirmation.glyph, title: confirmation.title, message: confirmation.message) {
            if confirmation.kind == .options {
                VStack(alignment: .leading, spacing: Metrics.Spacing.s) {
                    ForEach(Array(confirmation.actions.enumerated()), id: \.offset) { _, action in
                        DialogChoiceButton(action: action) { run(action) }
                    }
                }
            }
            ForEach(Array(confirmation.commands.enumerated()), id: \.offset) { _, command in
                CommandStrip(command: command.text, note: command.note, identifier: command.identifier)
            }
        } buttons: {
            if let cancelTitle = confirmation.cancelTitle {
                DialogCancelButton(title: cancelTitle, identifier: confirmation.cancelIdentifier) {
                    onFinish()
                    confirmation.cancelAction()
                }
            }
            if confirmation.kind != .options {
                ForEach(Array(confirmation.actions.enumerated()), id: \.offset) { _, action in
                    DialogConfirmButton(title: action.title, isDestructive: action.isDestructive, isDefault: action.isDefault, identifier: action.identifier) { run(action) }
                }
            }
        }
        .onExitCommand {
            onFinish()
            confirmation.cancelAction()
        }
    }

    private func run(_ action: DialogAction) {
        onFinish()
        action.perform()
    }
}

private struct DialogChoiceButton: View {
    let action: DialogAction
    let perform: () -> Void

    var body: some View {
        Button(action: perform) {
            VStack(alignment: .leading, spacing: Metrics.Spacing.xxs) {
                Text(action.title)
                    .font(Metrics.Font.title.weight(.semibold))
                    .foregroundStyle(action.isDestructive ? Palette.Status.deleted.ink.color : Palette.Text.primary.color)
                if let command = action.command {
                    Text(command)
                        .font(Metrics.Font.monoCaption)
                        .foregroundStyle(Palette.Text.secondary.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.Sheet.commandStripInset)
            .padding(.vertical, Metrics.Spacing.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(DialogChoiceStyle(isDestructive: action.isDestructive))
        .keyboardShortcut(action.isDefault ? .defaultAction : nil)
        .accessibilityLabel(action.title)
        .optionalIdentifier(action.identifier)
    }
}

private struct DialogChoiceStyle: ButtonStyle {
    let isDestructive: Bool

    func makeBody(configuration: Configuration) -> some View {
        DialogChoiceBody(configuration: configuration, isDestructive: isDestructive)
    }
}

private struct DialogChoiceBody: View {
    let configuration: ButtonStyleConfiguration
    let isDestructive: Bool
    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous)
        configuration.label
            .background(isHovered ? (isDestructive ? Palette.Status.deleted.tint.color : Palette.Accent.tint.color) : Palette.Surface.well.color, in: shape)
            .overlay(shape.strokeBorder(isHovered && isDestructive ? Palette.Status.deleted.ink.color : Palette.Surface.border.color, lineWidth: Metrics.Line.hairline))
            .opacity(configuration.isPressed ? Metrics.Opacity.hint : 1)
            .onHover { isHovered = $0 }
    }
}

private struct MorkConfirmationSheet: View {
    let confirmation: MorkConfirmation?
    @State private var retained: MorkConfirmation?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let shown = retained ?? confirmation {
                MorkConfirmationView(confirmation: shown) { dismiss() }
            }
        }
        .onAppear { retained = confirmation }
    }
}

extension View {
    func morkConfirmation(isPresented: Binding<Bool>, _ make: @escaping () -> MorkConfirmation) -> some View {
        sheet(isPresented: isPresented) {
            MorkConfirmationSheet(confirmation: make())
        }
    }

    func morkConfirmation<Value>(item: Binding<Value?>, _ make: @escaping (Value) -> MorkConfirmation) -> some View {
        sheet(isPresented: Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })) {
            MorkConfirmationSheet(confirmation: item.wrappedValue.map(make))
        }
    }

    func dialogSurface() -> some View {
        background(Palette.Surface.dialog.color)
    }

    @ViewBuilder
    func optionalIdentifier(_ identifier: String?) -> some View {
        if let identifier {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}
