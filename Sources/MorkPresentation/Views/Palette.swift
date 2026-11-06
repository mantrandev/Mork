import AppKit
import SwiftUI

struct HexColor: Hashable, Sendable, CustomStringConvertible {
    let red: Double
    let green: Double
    let blue: Double

    init(hex: UInt32) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
    }

    var luminance: Double {
        0.2126 * Self.linear(red) + 0.7152 * Self.linear(green) + 0.0722 * Self.linear(blue)
    }

    func contrast(with other: HexColor) -> Double {
        let lighter = max(luminance, other.luminance)
        let darker = min(luminance, other.luminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    func distance(to other: HexColor) -> Double {
        ((red - other.red) * (red - other.red) + (green - other.green) * (green - other.green) + (blue - other.blue) * (blue - other.blue)).squareRoot()
    }

    var nsColor: NSColor { NSColor(srgbRed: red, green: green, blue: blue, alpha: 1) }

    var description: String {
        String(format: "#%02X%02X%02X", Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }

    private static func linear(_ channel: Double) -> Double {
        channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }
}

struct ColorToken: Hashable, @unchecked Sendable {
    let light: HexColor
    let dark: HexColor
    let nsColor: NSColor
    let color: Color

    init(light: UInt32, dark: UInt32) {
        self.init(light: HexColor(hex: light), dark: HexColor(hex: dark))
    }

    init(light: HexColor, dark: HexColor) {
        self.light = light
        self.dark = dark
        let lightColor = light.nsColor
        let darkColor = dark.nsColor
        nsColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? darkColor : lightColor
        }
        color = Color(nsColor: nsColor)
    }

    static func == (lhs: ColorToken, rhs: ColorToken) -> Bool {
        lhs.light == rhs.light && lhs.dark == rhs.dark
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(light)
        hasher.combine(dark)
    }
}

enum Palette {
    enum Surface {
        static let window = ColorToken(light: 0xFFFFFF, dark: 0x1C1D1E)
        static let sidebar = ColorToken(light: 0xF3F4F4, dark: 0x151617)
        static let rowAlt = ColorToken(light: 0xF6F7F7, dark: 0x232526)
        static let raised = ColorToken(light: 0xFAFAFA, dark: 0x262829)
        static let border = ColorToken(light: 0xE1E3E3, dark: 0x333537)
        static let borderStrong = ColorToken(light: 0xCDD0D0, dark: 0x454749)
    }

    enum Text {
        static let primary = ColorToken(light: 0x1B1D1E, dark: 0xECEDED)
        static let secondary = ColorToken(light: 0x5B6063, dark: 0xA7ABAE)
        static let tertiary = ColorToken(light: 0x6B7073, dark: 0x8A8F92)
    }

    enum Accent {
        static let fill = ColorToken(light: 0x3F5689, dark: 0x8FA3CC)
        static let onFill = ColorToken(light: 0xFFFFFF, dark: 0x0E1424)
        static let tint = ColorToken(light: 0xE3E8F4, dark: 0x28334F)
        static let text = ColorToken(light: 0x3F5689, dark: 0xB4C2E0)
        static let glow = ColorToken(light: 0x3F5689, dark: 0x8FA3CC)
        static let tileFill = ColorToken(light: 0x1D2740, dark: 0x2A3652)
        static let tileLabel = ColorToken(light: 0x3DD6A8, dark: 0x3DD6A8)
    }

    struct Status: Hashable, Sendable {
        let ink: ColorToken
        let tint: ColorToken

        static let onFill = ColorToken(light: 0xFFFFFF, dark: 0x0E1012)

        static let added = Status(ink: ColorToken(light: 0x1E7A3C, dark: 0x5BD07E), tint: ColorToken(light: 0xDDF3E3, dark: 0x173E26))
        static let modified = Status(ink: ColorToken(light: 0x1F5FBF, dark: 0x6AA9FF), tint: ColorToken(light: 0xDEEAFB, dark: 0x1A3250))
        static let deleted = Status(ink: ColorToken(light: 0xC0322B, dark: 0xFF7A6E), tint: ColorToken(light: 0xFBE2E0, dark: 0x4A2320))
        static let renamed = Status(ink: ColorToken(light: 0x7B3FC4, dark: 0xC79BFF), tint: ColorToken(light: 0xEEE3FA, dark: 0x352349))
        static let conflict = Status(ink: ColorToken(light: 0xA8500A, dark: 0xF5A33B), tint: ColorToken(light: 0xFCEBDB, dark: 0x46301A))
        static let untracked = Status(ink: ColorToken(light: 0x60666A, dark: 0x9CA1A4), tint: ColorToken(light: 0xEEF0F0, dark: 0x2C2F31))

        static let all: [Status] = [added, modified, deleted, renamed, conflict, untracked]
    }

    enum Diff {
        static let addedLine = ColorToken(light: 0xE3F5E8, dark: 0x1C3326)
        static let addedGutter = ColorToken(light: 0xCDEED7, dark: 0x173E26)
        static let addedWord = ColorToken(light: 0xA9E3BB, dark: 0x245A38)
        static let deletedLine = ColorToken(light: 0xFCE6E4, dark: 0x3D2220)
        static let deletedGutter = ColorToken(light: 0xF9D4D1, dark: 0x4A2320)
        static let deletedWord = ColorToken(light: 0xF5B8B3, dark: 0x6B2F2A)
        static let hunk = ColorToken(light: 0xF3F4F4, dark: 0x262829)
        static let gutter = ColorToken(light: 0xF6F7F7, dark: 0x232526)
        static let editedLine = ColorToken(light: 0xFFF3C4, dark: 0x5A5010)
    }

    enum Ink {
        static let hover: Double = 0.07
        static let selection: Double = 0.08
        static let laneFill: Double = 0.12
        static let focusRing: Double = 0.45
    }
}
