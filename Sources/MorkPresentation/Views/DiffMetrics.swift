import AppKit
import MorkDomain
import SwiftUI

struct DiffMetrics: Equatable {
    static let standard = DiffMetrics()

    let fontSize: CGFloat
    let numberFontSize: CGFloat
    let rowHeight: CGFloat
    let characterWidth: CGFloat
    let numberCharacterWidth: CGFloat
    let lineHeight: CGFloat
    let tabWidth: Int
    let wrapsLines: Bool
    let showsInvisibles: Bool

    init(fontSize: CGFloat = Metrics.FontSize.body, tabWidth: Int = 4, wrapsLines: Bool = false, showsInvisibles: Bool = false) {
        self.fontSize = fontSize
        self.tabWidth = tabWidth
        self.wrapsLines = wrapsLines
        self.showsInvisibles = showsInvisibles
        numberFontSize = fontSize * Metrics.FontSize.caption / Metrics.FontSize.body
        rowHeight = (fontSize * Metrics.Diff.rowHeight / Metrics.FontSize.body).rounded()
        characterWidth = Self.width(of: fontSize)
        numberCharacterWidth = Self.width(of: numberFontSize)
        lineHeight = ceil(NSLayoutManager().defaultLineHeight(for: .monospacedSystemFont(ofSize: fontSize, weight: .regular)))
    }

    init(settings: DiffSettings) {
        self.init(fontSize: CGFloat(settings.fontSize), tabWidth: settings.tabWidth, wrapsLines: settings.wrapsLines, showsInvisibles: settings.showsInvisibles)
    }

    func wrapLayout(textWidth: CGFloat) -> DiffWrapLayout? {
        guard wrapsLines else { return nil }
        return DiffWrapLayout(columns: DiffWrap.columns(fitting: textWidth, characterWidth: characterWidth), characterWidth: characterWidth, rowHeight: rowHeight, lineHeight: lineHeight)
    }

    private static func width(of size: CGFloat) -> CGFloat {
        ("0" as NSString).size(withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: size, weight: .regular)]).width
    }
}

enum DiffWrap {
    static func columns(fitting width: CGFloat, characterWidth: CGFloat) -> Int {
        guard characterWidth > 0 else { return 1 }
        return max(1, Int(((width - Metrics.Diff.textPadding * 2) / characterWidth).rounded(.down)))
    }

    static func rows(columns: Int, perRow: Int) -> Int {
        max(1, (columns + max(perRow, 1) - 1) / max(perRow, 1))
    }

    static func fieldWidth(columns: Int, characterWidth: CGFloat) -> CGFloat {
        CGFloat(columns) * characterWidth + Metrics.Diff.textPadding * 2 + Metrics.Diff.wrapSlack
    }
}

enum DiffTabs {
    static let spaceMark: Character = "·"
    static let tabMark: Character = "→"

    static func expand(_ text: String, changed: Range<Int>?, width: Int) -> (text: String, changed: Range<Int>?) {
        let result = expand(text, changed: changed, width: width, marksInvisiblesAfter: nil)
        return (result.text, result.changed)
    }

    static func expand(_ text: String, changed: Range<Int>?, width: Int, marksInvisiblesAfter start: Int?) -> (text: String, changed: Range<Int>?, marks: [Int]) {
        guard text.contains("\t") || (start != nil && text.contains(" ")) else { return (text, changed, []) }
        var expanded = ""
        var offsets: [Int] = []
        var marks: [Int] = []
        offsets.reserveCapacity(text.count + 1)
        var column = 0
        for (index, character) in text.enumerated() {
            offsets.append(column)
            let count = character == "\t" ? width - column % width : 1
            let marksInvisible = start.map { index >= $0 } ?? false
            if character == "\t" {
                if marksInvisible {
                    marks.append(column)
                    expanded.append(tabMark)
                    expanded += String(repeating: " ", count: count - 1)
                } else {
                    expanded += String(repeating: " ", count: count)
                }
            } else if character == " ", marksInvisible {
                marks.append(column)
                expanded.append(spaceMark)
            } else {
                expanded.append(character)
            }
            column += count
        }
        offsets.append(column)
        let mapped = changed.flatMap { range -> Range<Int>? in
            guard range.upperBound < offsets.count else { return nil }
            return offsets[range.lowerBound]..<offsets[range.upperBound]
        }
        return (expanded, mapped, marks)
    }

    static func columns(of text: String, width: Int) -> Int {
        text.reduce(0) { column, character in
            column + (character == "\t" ? width - column % width : 1)
        }
    }
}

private struct DiffMetricsKey: EnvironmentKey {
    static let defaultValue = DiffMetrics.standard
}

extension EnvironmentValues {
    var diffMetrics: DiffMetrics {
        get { self[DiffMetricsKey.self] }
        set { self[DiffMetricsKey.self] = newValue }
    }
}
