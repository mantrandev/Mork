import AppKit
import SwiftUI

enum FolderPicker {
    @MainActor
    static func pick(prompt: String) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = prompt
        return panel.runModal() == .OK ? panel.url : nil
    }
}

extension View {
    func errorAlert(_ message: Binding<String?>, hiddenFiles: [String] = [], unhide: (([String]) -> Void)? = nil) -> some View {
        sheet(isPresented: Binding(get: { message.wrappedValue != nil }, set: { if !$0 { message.wrappedValue = nil } })) {
            ErrorSheet(message: message.wrappedValue ?? "", hiddenFiles: hiddenFiles, unhide: unhide)
        }
    }
}

struct ErrorSheet: View {
    let message: String
    let hiddenFiles: [String]
    let unhide: (([String]) -> Void)?
    private let report: ErrorReport
    @Environment(\.dismiss) private var dismiss

    init(message: String, hiddenFiles: [String] = [], unhide: (([String]) -> Void)? = nil) {
        self.message = message
        self.hiddenFiles = hiddenFiles
        self.unhide = unhide
        report = ErrorReport(message: message)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Sheet.sectionSpacing) {
            HStack(alignment: .top, spacing: Metrics.Sheet.headerGap) {
                DialogGlyphTile(kind: .error)
                VStack(alignment: .leading, spacing: Metrics.Spacing.xs) {
                    Text(report.title)
                        .font(Metrics.Font.heading)
                        .foregroundStyle(Palette.Text.primary.color)
                    CappedHeightLayout(cap: Metrics.Sheet.errorMessageHeight) {
                        summaryText.hidden()
                        ScrollView { summaryText }
                            .scrollBounceBehavior(.basedOnSize)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(report.command == nil ? "error.message" : "error.summary")
            if report.command != nil {
                CappedHeightLayout(cap: Metrics.Sheet.outputMaximumHeight) {
                    output.hidden()
                    ScrollView { output }
                        .scrollBounceBehavior(.basedOnSize)
                }
                .background(Palette.Surface.well.color, in: RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("error.message")
            }
            if let unhide, !hiddenFiles.isEmpty {
                DialogNote(text: ErrorReport.hiddenFilesNote(hiddenFiles), tone: .warning)
                    .accessibilityIdentifier("error.hiddenFiles")
                DialogButtonRow {
                    DialogCancelButton(title: "OK", identifier: "error.ok") { dismiss() }
                    DialogConfirmButton(title: "Unhide Files", identifier: "error.unhide") {
                        let paths = hiddenFiles
                        dismiss()
                        unhide(paths)
                    }
                }
            } else {
                DialogButtonRow {
                    DialogConfirmButton(title: "OK", identifier: "error.ok") { dismiss() }
                }
            }
        }
        .padding(Metrics.Sheet.padding)
        .frame(width: DialogKind.error.width)
        .dialogSurface()
        .onExitCommand { dismiss() }
    }

    private var summaryText: some View {
        Text(report.summary)
            .font(Metrics.Font.title)
            .foregroundStyle(Palette.Text.secondary.color)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var output: some View {
        CommandOutputBox(command: report.command, lines: report.output)
    }
}

private struct CappedHeightLayout: Layout {
    let cap: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let measure = subviews.first else { return .zero }
        let content = measure.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        return CGSize(width: proposal.width ?? content.width, height: min(content.height, cap))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        subviews[0].place(at: bounds.origin, proposal: .zero)
        subviews[1].place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}

struct TextInputSheet: View {
    let title: String
    let placeholder: String
    let secondaryPlaceholder: String?
    let confirmTitle: String
    let identifier: String
    var message: String?
    var glyph = "plus"
    var command: ((String) -> String)?
    var allowsEmpty = false
    let onConfirm: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var secondary = ""

    var body: some View {
        DialogScaffold(kind: .form, glyph: glyph, title: title, message: message) {
            VStack(alignment: .leading, spacing: Metrics.Sheet.rowSpacing) {
                DialogTextField(placeholder: placeholder, text: $text, identifier: "\(identifier).name", onSubmit: confirm)
                if let secondaryPlaceholder {
                    DialogTextField(placeholder: secondaryPlaceholder, text: $secondary, identifier: "\(identifier).message")
                }
            }
            if let command {
                CommandStrip(command: command(text), identifier: "\(identifier).command")
            }
        } buttons: {
            DialogCancelButton { dismiss() }
            DialogConfirmButton(title: confirmTitle, identifier: "\(identifier).confirm", action: confirm)
                .disabled(isEmpty)
        }
    }

    private var isEmpty: Bool {
        !Self.canConfirm(text: text, hasSecondaryField: secondaryPlaceholder != nil, allowsEmpty: allowsEmpty)
    }

    static func canConfirm(text: String, hasSecondaryField: Bool, allowsEmpty: Bool) -> Bool {
        allowsEmpty || hasSecondaryField || !text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func confirm() {
        guard !isEmpty else { return }
        onConfirm(text, secondary)
        dismiss()
    }
}

struct MenuEntry {
    let title: String
    var systemImage: String? = nil
    var image: NSImage? = nil
    var dotColor: Color? = nil
    var detail: String? = nil
    var isChecked = false
    var keyEquivalent = ""
    var identifier: String? = nil
    var isSeparator = false
    var isEnabled = true
    var children: [MenuEntry] = []
    let action: () -> Void

    static var separator: MenuEntry { MenuEntry(title: "", isSeparator: true) {} }
}

@MainActor
final class MenuAnchor {
    fileprivate weak var view: NSView?

    func popUp(_ entries: [MenuEntry]) {
        guard let view else { return }
        let menu = Self.menu(entries)
        let y = view.isFlipped ? view.bounds.maxY + Metrics.Spacing.xs : view.bounds.minY - Metrics.Spacing.xs
        menu.popUp(positioning: nil, at: NSPoint(x: view.bounds.minX, y: y), in: view)
    }

    static func menu(_ entries: [MenuEntry]) -> NSMenu {
        let result = NSMenu()
        result.autoenablesItems = false
        for entry in entries {
            guard !entry.isSeparator else {
                result.addItem(.separator())
                continue
            }
            let item = ClosureMenuItem(title: entry.title, action: entry.action)
            item.keyEquivalent = entry.keyEquivalent
            item.state = entry.isChecked ? .on : .off
            item.image = entry.image ?? entry.systemImage.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
            item.isEnabled = entry.isEnabled
            if let identifier = entry.identifier { item.setAccessibilityIdentifier(identifier) }
            if !entry.children.isEmpty { item.submenu = menu(entry.children) }
            result.addItem(item)
        }
        return result
    }
}

struct MenuAnchorView: NSViewRepresentable {
    let anchor: MenuAnchor

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        anchor.view = view
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        anchor.view = view
    }
}

private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, action handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func run() {
        handler()
    }
}

struct Hairline: View {
    var isVertical = false

    var body: some View {
        Rectangle()
            .fill(Palette.Surface.border.color)
            .frame(width: isVertical ? Metrics.Line.hairline : nil, height: isVertical ? nil : Metrics.Line.hairline)
            .accessibilityHidden(true)
    }
}

struct ToolbarGroupSeparator: View {
    @Environment(\.toolbarShowsCaptions) private var showsCaptions

    var body: some View {
        Rectangle()
            .fill(Palette.Surface.border.color)
            .frame(width: Metrics.Line.hairline, height: showsCaptions ? Metrics.Toolbar.separatorHeight : Metrics.Toolbar.iconOnlySeparatorHeight)
            .padding(.horizontal, showsCaptions ? 0 : Metrics.Toolbar.iconOnlySeparatorPadding)
            .accessibilityHidden(true)
    }
}

struct ToolbarCaptionButton: View {
    static let spacing = Metrics.Toolbar.spacing

    let title: String
    let systemImage: String
    var showsMenuIndicator = false
    var isCompact = false
    var showsCaption = true
    var isRunning = false
    var isActive = false
    var badge = 0
    var captionMaxWidth: CGFloat? = nil
    var symbolRotation: Angle = .zero
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.toolbarShowsCaptions) private var toolbarShowsCaptions
    @State private var isHovered = false

    private var hasCaption: Bool { showsCaption && toolbarShowsCaptions }

    private var minimumWidth: CGFloat {
        if !hasCaption { return Metrics.Toolbar.iconOnlyWidth }
        return isCompact ? Metrics.HitTarget.toolbarCompactWidth : Metrics.HitTarget.toolbarWidth
    }

    private var countBadge: some View {
        CountBadge(count: badge).fixedSize()
    }

    var body: some View {
        let style = ToolbarItemStyle(isEnabled: isEnabled, isActive: isActive, isHovered: isHovered)
        Button(action: action) {
            VStack(spacing: Metrics.Spacing.xs) {
                HStack(spacing: Metrics.Spacing.xxs) {
                    if isRunning {
                        ProgressView()
                            .controlSize(.small)
                            .frame(height: Metrics.Toolbar.glyphHeight)
                    } else {
                        HStack(spacing: -Metrics.Toolbar.badgeOverlap) {
                            if badge > 0 { countBadge.hidden() }
                            Image(systemName: systemImage)
                                .font(.system(size: hasCaption ? Metrics.Toolbar.captionIcon : Metrics.Toolbar.iconOnlyIcon, weight: .regular))
                                .rotationEffect(symbolRotation)
                                .frame(height: Metrics.Toolbar.glyphHeight)
                            if badge > 0 {
                                countBadge
                                    .offset(y: -Metrics.Toolbar.badgeRise)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    if showsMenuIndicator {
                        Image(systemName: "chevron.down")
                            .font(.system(size: Metrics.Icon.menuIndicator, weight: .bold))
                    }
                }
                .foregroundStyle(style.glyph)
                if hasCaption {
                    Text(title)
                        .font(Metrics.Font.caption.weight(.medium))
                        .foregroundStyle(style.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: captionMaxWidth)
                }
            }
            .padding(.horizontal, hasCaption ? Metrics.Spacing.xs : Metrics.Spacing.xxs)
            .frame(minWidth: minimumWidth, minHeight: hasCaption ? Metrics.Toolbar.itemHeight : Metrics.Toolbar.iconOnlyWidth)
            .background(style.fill, in: RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(title)
        .accessibilityValue(isRunning ? "running" : badge > 0 ? "\(badge)" : "")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

struct ToolbarItemStyle: Equatable {
    let glyph: Color
    let caption: Color
    let fill: Color

    init(isEnabled: Bool, isActive: Bool, isHovered: Bool) {
        if !isEnabled {
            glyph = Palette.Text.tertiary.color
            caption = Palette.Text.tertiary.color
            fill = .clear
        } else if isActive {
            glyph = Palette.Accent.text.color
            caption = Palette.Accent.text.color
            fill = Palette.Accent.tint.color
        } else {
            glyph = Palette.Text.secondary.color
            caption = Palette.Text.primary.color
            fill = isHovered ? Palette.Text.primary.color.opacity(Palette.Ink.hover) : .clear
        }
    }
}

struct ToolbarSplitButton: View {
    let title: String
    let systemImage: String
    let identifier: String
    let menuIdentifier: String
    let action: () -> Void
    let menuAction: () -> Void
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.toolbarShowsCaptions) private var toolbarShowsCaptions
    @State private var hovered: Part?

    private enum Part {
        case main
        case menu
    }

    var body: some View {
        let style = ToolbarItemStyle(isEnabled: isEnabled, isActive: false, isHovered: false)
        VStack(spacing: Metrics.Spacing.xs) {
            HStack(spacing: 0) {
                part(.main, action: action) {
                    Image(systemName: systemImage)
                        .font(.system(size: toolbarShowsCaptions ? Metrics.Toolbar.captionIcon : Metrics.Toolbar.iconOnlyIcon, weight: .regular))
                        .frame(width: Metrics.Toolbar.splitMainWidth, height: Metrics.Toolbar.glyphHeight)
                }
                .accessibilityLabel(title)
                .accessibilityIdentifier(identifier)
                Rectangle()
                    .fill(Palette.Surface.borderStrong.color)
                    .frame(width: Metrics.Line.hairline, height: Metrics.Toolbar.splitDividerHeight)
                part(.menu, action: menuAction) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: Metrics.Icon.menuIndicator, weight: .bold))
                        .frame(width: Metrics.Toolbar.splitMenuWidth, height: Metrics.Toolbar.glyphHeight)
                }
                .accessibilityLabel("\(title) Menu")
                .accessibilityIdentifier(menuIdentifier)
            }
            .foregroundStyle(style.glyph)
            if toolbarShowsCaptions {
                Text(title)
                    .font(Metrics.Font.caption.weight(.medium))
                    .foregroundStyle(style.caption)
                    .lineLimit(1)
            }
        }
        .frame(minWidth: Metrics.HitTarget.toolbarWidth, minHeight: toolbarShowsCaptions ? Metrics.Toolbar.itemHeight : Metrics.Toolbar.iconOnlyWidth)
    }

    private func part<Label: View>(_ part: Part, action: @escaping () -> Void, @ViewBuilder label: () -> Label) -> some View {
        Button(action: action) {
            label()
                .background(hovered == part && isEnabled ? Palette.Text.primary.color.opacity(Palette.Ink.hover) : .clear, in: RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { inside in
            if inside { hovered = part } else if hovered == part { hovered = nil }
        }
    }
}

private struct ToolbarShowsCaptionsKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var toolbarShowsCaptions: Bool {
        get { self[ToolbarShowsCaptionsKey.self] }
        set { self[ToolbarShowsCaptionsKey.self] = newValue }
    }
}

struct PanelHeader<Leading: View, Trailing: View>: View {
    let title: String
    let count: Int?
    var tint: Color? = nil
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Metrics.Spacing.s) {
            leading
            Text(title)
                .font(Metrics.Font.title.weight(.semibold))
                .foregroundStyle(Palette.Text.primary.color)
            if let count {
                if let tint {
                    Text("\(count)")
                        .font(Metrics.Font.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(Palette.Status.onFill.color)
                        .padding(.horizontal, Metrics.Spacing.xs + Metrics.Spacing.xxs)
                        .frame(minWidth: Metrics.Control.badge, minHeight: Metrics.Control.badge)
                        .background(tint, in: Capsule())
                } else {
                    CountBadge(count: count, isAccent: false)
                }
            }
            Spacer(minLength: Metrics.Spacing.s)
            trailing
        }
        .padding(.leading, Metrics.Spacing.m)
        .padding(.trailing, Metrics.Spacing.s)
        .frame(height: Metrics.Panel.header)
    }
}

extension PanelHeader where Leading == EmptyView {
    init(title: String, count: Int?, tint: Color? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.init(title: title, count: count, tint: tint, leading: { EmptyView() }, trailing: trailing)
    }
}

struct LogLinesList: View {
    static let rowHeight = Metrics.LineHeight.body

    let lines: [String]

    var body: some View {
        ScrollViewReader { proxy in
            List(lines.indices, id: \.self) { index in
                Text(lines[index])
                    .font(Metrics.Font.monoCaption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, minHeight: Self.rowHeight, alignment: .leading)
                    .listRowInsets(EdgeInsets(top: 0, leading: Metrics.Spacing.s, bottom: 0, trailing: Metrics.Spacing.s))
                    .listRowSeparator(.hidden)
                    .id(index)
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, Self.rowHeight)
            .onChange(of: lines.count) { _, count in
                if count > 0 { proxy.scrollTo(count - 1, anchor: .bottom) }
            }
        }
    }
}
