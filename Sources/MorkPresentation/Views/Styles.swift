import SwiftUI

extension Palette.Status {
    static func status(for letter: Character) -> Palette.Status {
        switch letter {
        case "A": .added
        case "D": .deleted
        case "R", "C": .renamed
        case "U", "!": .conflict
        case "?", "I": .untracked
        default: .modified
        }
    }
}

struct MorkButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
        case destructive
        case destructiveConfirm
        case link
    }

    enum Size {
        case regular
        case small

        var height: CGFloat {
            switch self {
            case .regular: Metrics.Control.regular
            case .small: Metrics.Control.small
            }
        }

        var font: Font {
            switch self {
            case .regular: Metrics.Font.title
            case .small: Metrics.Font.body
            }
        }

        var padding: CGFloat {
            switch self {
            case .regular: Metrics.Spacing.m
            case .small: Metrics.Spacing.s
            }
        }
    }

    var kind: Kind = .secondary
    var size: Size = .regular

    func makeBody(configuration: Configuration) -> some View {
        MorkButtonBody(configuration: configuration, kind: kind, size: size)
    }
}

extension MorkButtonStyle.Kind {
    var weight: Font.Weight {
        switch self {
        case .primary, .destructiveConfirm: .semibold
        case .secondary, .destructive, .link: .medium
        }
    }

    func foreground(isEnabled: Bool) -> ColorToken {
        guard isEnabled else { return Palette.Text.tertiary }
        switch self {
        case .primary: return Palette.Accent.onFill
        case .secondary: return Palette.Text.primary
        case .destructive: return Palette.Status.deleted.ink
        case .destructiveConfirm: return Palette.Status.onFill
        case .link: return Palette.Accent.text
        }
    }

    func background(isEnabled: Bool, isHovered: Bool) -> ColorToken? {
        guard isEnabled else { return self == .link ? nil : Palette.Status.untracked.tint }
        switch self {
        case .primary: return Palette.Accent.fill
        case .secondary: return isHovered ? Palette.Surface.rowAlt : Palette.Surface.dialog
        case .destructive: return isHovered ? Palette.Status.deleted.tint : Palette.Surface.dialog
        case .destructiveConfirm: return Palette.Status.deleted.ink
        case .link: return nil
        }
    }

    func border(isEnabled: Bool) -> ColorToken? {
        guard isEnabled else { return nil }
        switch self {
        case .secondary, .destructive: return Palette.Surface.borderStrong
        case .primary, .destructiveConfirm, .link: return nil
        }
    }
}

private struct MorkButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: MorkButtonStyle.Kind
    let size: MorkButtonStyle.Size
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .font(size.font.weight(kind.weight))
            .lineLimit(1)
            .foregroundStyle(kind.foreground(isEnabled: isEnabled).color)
            .padding(.horizontal, kind == .link ? 0 : size.padding)
            .frame(minHeight: size.height)
            .background(kind.background(isEnabled: isEnabled, isHovered: isHovered)?.color ?? .clear, in: shape)
            .overlay { if let border = kind.border(isEnabled: isEnabled) { shape.strokeBorder(border.color, lineWidth: Metrics.Line.hairline) } }
            .contentShape(shape)
            .opacity(configuration.isPressed ? Metrics.Opacity.pressed : 1)
            .onHover { isHovered = $0 }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous)
    }
}

extension ButtonStyle where Self == MorkButtonStyle {
    static var morkPrimary: MorkButtonStyle { MorkButtonStyle(kind: .primary) }
    static var morkSecondary: MorkButtonStyle { MorkButtonStyle(kind: .secondary) }
    static var morkDestructive: MorkButtonStyle { MorkButtonStyle(kind: .destructive) }
    static var morkDestructiveConfirm: MorkButtonStyle { MorkButtonStyle(kind: .destructiveConfirm) }
    static var morkLink: MorkButtonStyle { MorkButtonStyle(kind: .link) }
    static func mork(_ kind: MorkButtonStyle.Kind, size: MorkButtonStyle.Size) -> MorkButtonStyle { MorkButtonStyle(kind: kind, size: size) }
}

struct CountBadge: View {
    let count: Int
    var isAccent = true

    var body: some View {
        Text("\(count)")
            .font(Metrics.Font.caption.weight(.bold).monospacedDigit())
            .foregroundStyle(isAccent ? Palette.Accent.onFill.color : Palette.Text.secondary.color)
            .padding(.horizontal, Metrics.Spacing.xs + Metrics.Spacing.xxs)
            .frame(minWidth: Metrics.Control.badge, minHeight: Metrics.Control.badge)
            .background(isAccent ? Palette.Accent.fill.color : Palette.Surface.border.color, in: Capsule())
    }
}
