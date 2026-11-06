import AppKit
import MorkDomain
import SwiftUI

struct HunkHoverButton: Equatable {
    let title: String
    let identifier: String
    let action: HunkAction
    let appliesToLines: Bool
    let isEnabled: Bool
    let help: String
}

enum HunkHoverButtons {
    static func make(actions: [HunkAction], hunk: Int, selectedLines: Int, selectionHasChanges: Bool, isBusy: Bool) -> [HunkHoverButton] {
        let appliesToLines = selectedLines > 0
        return actions.map { action in
            HunkHoverButton(
                title: title(action),
                identifier: appliesToLines ? "hunk.\(action.rawValue)Lines.\(hunk)" : "hunk.\(action.rawValue).\(hunk)",
                action: action,
                appliesToLines: appliesToLines,
                isEnabled: !isBusy && (!appliesToLines || selectionHasChanges),
                help: help(action, appliesToLines: appliesToLines, selectionHasChanges: selectionHasChanges)
            )
        }
    }

    private static func title(_ action: HunkAction) -> String {
        switch action {
        case .stage: "Stage"
        case .unstage: "Unstage"
        case .discard: "Discard Changes…"
        }
    }

    private static func help(_ action: HunkAction, appliesToLines: Bool, selectionHasChanges: Bool) -> String {
        let flags = switch action {
        case .stage: "--cached "
        case .unstage: "--cached --reverse "
        case .discard: "--reverse "
        }
        guard appliesToLines else { return "git apply \(flags)with a patch of this hunk" }
        return selectionHasChanges ? "git apply \(flags)with a patch of only the selected lines" : "Only unchanged lines are selected"
    }
}

struct DiffHunkRows {
    private var hunks: [Int?] = []
    private var ranges: [Int: ClosedRange<Int>] = [:]

    init(blocks: [DiffBlock] = []) {
        var current: Int?
        for (row, block) in blocks.enumerated() {
            switch block {
            case .file:
                current = nil
            case let .hunk(line):
                current = line.hunk
            case let .line(line):
                current = line.source?.hunk ?? current
            }
            hunks.append(current)
            guard let current else { continue }
            if let range = ranges[current] {
                ranges[current] = range.lowerBound...row
            } else {
                ranges[current] = row...row
            }
        }
    }

    func hunk(atRow row: Int) -> Int? {
        hunks.indices.contains(row) ? hunks[row] : nil
    }

    func range(of hunk: Int) -> ClosedRange<Int>? {
        ranges[hunk]
    }
}

struct HunkHoverActions: View {
    let buttons: [HunkHoverButton]
    let run: (HunkHoverButton) -> Void

    var body: some View {
        HStack(spacing: Metrics.Spacing.xs) {
            ForEach(buttons, id: \.identifier) { button in
                Button(button.title, role: button.action == .discard ? .destructive : nil) { run(button) }
                    .buttonStyle(.mork(button.action == .discard ? .destructive : .secondary, size: .small))
                    .disabled(!button.isEnabled)
                    .help(button.help)
                    .accessibilityIdentifier(button.identifier)
            }
        }
        .fixedSize()
    }
}

final class DiffHoverOutline: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.zPosition = 1
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.borderWidth = Metrics.Diff.hoverOutline
        layer?.borderColor = Palette.Accent.fill.nsColor.cgColor
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
