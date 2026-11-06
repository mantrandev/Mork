import AppKit
import SwiftUI

enum CommitGraphPalette {
    typealias Entry = ColorToken

    static let entries: [Entry] = [
        Entry(light: 0xC4680A, dark: 0xF5A33B),
        Entry(light: 0x9A7600, dark: 0xF4D04A),
        Entry(light: 0xCC3A22, dark: 0xEE5A45),
        Entry(light: 0x8C6A4C, dark: 0xB39578),
        Entry(light: 0x8A4FD6, dark: 0xB784F0),
        Entry(light: 0x1F6FD0, dark: 0x4DA6FF),
        Entry(light: 0x2E8530, dark: 0x6FCB5B),
        Entry(light: 0xC23A74, dark: 0xF0729F)
    ]

    static let lightBackgrounds = [Palette.Surface.window.light, Palette.Surface.rowAlt.light]
    static let darkBackgrounds = [Palette.Surface.window.dark, Palette.Surface.rowAlt.dark]

    static let colors: [Color] = entries.map(\.color)

    static func index(_ lane: Int) -> Int {
        lane % entries.count
    }

    static func color(_ lane: Int) -> Color {
        colors[index(lane)]
    }
}
