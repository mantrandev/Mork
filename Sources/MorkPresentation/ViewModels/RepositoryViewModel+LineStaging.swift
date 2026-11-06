import MorkDomain
import Foundation

public enum LineClick: Sendable {
    case replace
    case extend
    case toggle
}

extension RepositoryViewModel {
    public var selectedLineCount: Int { lineSelection.count }

    public func selectLine(_ id: DiffLineID, _ click: LineClick = .replace) {
        guard let patch, !hunkActions.isEmpty else { return }
        let dragStart = click == .extend ? lineAnchor ?? id : id
        let dragBase = click == .toggle ? lineSelection : DiffLineSelection()
        defer {
            lineDragStart = dragStart
            lineDragBase = dragBase
        }
        var updated = lineSelection
        switch click {
        case .replace:
            guard updated != DiffLineSelection([id]) else {
                clearLineSelection()
                return
            }
            updated = DiffLineSelection([id])
            lineAnchor = id
        case .toggle:
            updated.toggle(id)
            lineAnchor = id
        case .extend:
            if let anchor = lineAnchor {
                updated.insertRange(from: anchor, to: id, in: patch)
            } else {
                updated = DiffLineSelection([id])
                lineAnchor = id
            }
        }
        lineSelection = updated
    }

    public func dragLine(to id: DiffLineID) {
        guard let patch, !hunkActions.isEmpty, let start = lineDragStart else { return }
        var updated = lineDragBase
        updated.insertRange(from: start, to: id, in: patch)
        lineAnchor = start
        if updated != lineSelection { lineSelection = updated }
    }

    public func hasSelectedLines(inHunk hunk: Int) -> Bool {
        !lineSelection.lines(inHunk: hunk).isEmpty
    }

    public func clearLineSelection() {
        lineAnchor = nil
        lineDragStart = nil
        if !lineSelection.isEmpty { lineSelection = DiffLineSelection() }
    }

    public func applySelectedLines(_ action: HunkAction) async {
        guard case let .file(change, _) = selection, let patch, hunkActions.contains(action), lineSelectionHasChanges else { return }
        let lines = lineSelection
        if await perform({ try await $0.tools.applyLines.execute(action: action, selection: lines, patch: patch, change: change) }) {
            clearLineSelection()
        }
    }
}
