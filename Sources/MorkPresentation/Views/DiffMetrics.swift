import AppKit
import SwiftUI

struct DiffMetrics: Equatable {
    static let standard = DiffMetrics()

    let fontSize: CGFloat
    let numberFontSize: CGFloat
    let rowHeight: CGFloat
    let characterWidth: CGFloat
    let numberCharacterWidth: CGFloat
    let tabWidth: Int

    init(fontSize: CGFloat = Metrics.FontSize.body, tabWidth: Int = 4) {
        self.fontSize = fontSize
        self.tabWidth = tabWidth
        numberFontSize = fontSize * Metrics.FontSize.caption / Metrics.FontSize.body
        rowHeight = (fontSize * Metrics.Diff.rowHeight / Metrics.FontSize.body).rounded()
        characterWidth = Self.width(of: fontSize)
        numberCharacterWidth = Self.width(of: numberFontSize)
    }

    private static func width(of size: CGFloat) -> CGFloat {
        ("0" as NSString).size(withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: size, weight: .regular)]).width
    }
}

enum DiffTabs {
    static func expand(_ text: String, changed: Range<Int>?, width: Int) -> (text: String, changed: Range<Int>?) {
        guard text.contains("\t") else { return (text, changed) }
        var expanded = ""
        var offsets: [Int] = []
        offsets.reserveCapacity(text.count + 1)
        var column = 0
        for character in text {
            offsets.append(column)
            let count = character == "\t" ? width - column % width : 1
            if character == "\t" {
                expanded += String(repeating: " ", count: count)
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
        return (expanded, mapped)
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
