import SwiftUI

struct InlineDiffView: View {
    let document: DiffDocument

    var body: some View {
        let rows = InlineDiffRows.lines(of: document)
        Canvas(rendersAsynchronously: true) { context, size in
            let font = Metrics.Font.monoCaption
            let height = Metrics.CommitDetails.inlineLineHeight
            let numberWidth = Metrics.CommitDetails.inlineNumberWidth
            let gutterWidth = numberWidth * 2 + Metrics.Spacing.xs
            for (index, line) in rows.enumerated() {
                let rect = CGRect(x: 0, y: CGFloat(index) * height, width: size.width, height: height)
                let middle = rect.midY
                if let background = InlineDiffRows.background(of: line) {
                    context.fill(Path(rect), with: .color(background))
                }
                if line.kind == .hunk {
                    context.draw(Text(line.text).font(font).foregroundStyle(Palette.Text.secondary.color), at: CGPoint(x: Metrics.Spacing.s, y: middle), anchor: .leading)
                    continue
                }
                let colors = InlineDiffRows.gutter(of: line)
                context.fill(Path(CGRect(x: 0, y: rect.minY, width: gutterWidth, height: height)), with: .color(colors.fill))
                if let old = line.oldNumber {
                    context.draw(Text(String(old)).font(font).foregroundStyle(colors.number), at: CGPoint(x: numberWidth, y: middle), anchor: .trailing)
                }
                if let new = line.newNumber {
                    context.draw(Text(String(new)).font(font).foregroundStyle(colors.number), at: CGPoint(x: numberWidth * 2, y: middle), anchor: .trailing)
                }
                let text = DiffTabs.expand(line.text, changed: nil, width: document.tabWidth).text
                context.draw(Text(text).font(font).foregroundStyle(Palette.Text.primary.color), at: CGPoint(x: gutterWidth + Metrics.Spacing.s, y: middle), anchor: .leading)
            }
        }
        .frame(height: CGFloat(rows.count) * Metrics.CommitDetails.inlineLineHeight)
        .clipped()
        .accessibilityElement()
        .accessibilityAddTraits(.isStaticText)
        .accessibilityValue(rows.map(\.text).joined(separator: "\n"))
    }
}

enum InlineDiffRows {
    static func lines(of document: DiffDocument) -> [DiffLine] {
        document.blocks.compactMap { block in
            switch block {
            case .file: nil
            case let .hunk(line), let .line(line): line
            }
        }
    }

    static func background(of line: DiffLine) -> Color? {
        switch line.kind {
        case .addition: Palette.Diff.addedLine.color
        case .deletion: Palette.Diff.deletedLine.color
        case .hunk: Palette.Diff.hunk.color
        default: nil
        }
    }

    static func gutter(of line: DiffLine) -> (fill: Color, number: Color) {
        switch line.kind {
        case .addition: (Palette.Diff.addedGutter.color, Palette.Status.added.ink.color)
        case .deletion: (Palette.Diff.deletedGutter.color, Palette.Status.deleted.ink.color)
        default: (Palette.Diff.gutter.color, Palette.Text.tertiary.color)
        }
    }
}
