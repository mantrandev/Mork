import AppKit
import SwiftUI

enum HistoryPointerAction: Equatable {
    case extend
    case toggle
    case collapse
    case pass
}

enum HistoryKeyAction: Equatable {
    case selectAll
    case copy
    case preview
    case pass
}

enum HistoryInput {
    static func pointer(_ modifiers: NSEvent.ModifierFlags, clickCount: Int, isMultiSelection: Bool) -> HistoryPointerAction {
        let flags = modifiers.intersection(.deviceIndependentFlagsMask)
        guard clickCount == 1 || flags.contains(.command), !flags.contains(.control), !flags.contains(.option) else { return .pass }
        if flags.contains(.shift) { return .extend }
        if flags.contains(.command) { return .toggle }
        return isMultiSelection ? .collapse : .pass
    }

    static func key(_ characters: String?, modifiers: NSEvent.ModifierFlags) -> HistoryKeyAction {
        let flags = modifiers.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock)
        if flags.isEmpty, characters == " " { return .preview }
        guard flags == .command else { return .pass }
        switch characters?.lowercased() {
        case "a": return .selectAll
        case "c": return .copy
        default: return .pass
        }
    }
}

@MainActor
final class HistoryTableLink {
    weak var viewModel: RepositoryViewModel?
    var isInActiveTab = true
    private(set) weak var table: NSTableView?
    private var monitor: Any?

    func attach(_ table: NSTableView) {
        guard self.table !== table else { return }
        self.table = table
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .keyDown]) { [weak self] event in
            let consumed = MainActor.assumeIsolated { self?.consumes(event) ?? false }
            return consumed ? nil : event
        }
    }

    func detach() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    func consumes(_ event: NSEvent) -> Bool {
        guard isInActiveTab, let table, let viewModel, viewModel.pane == .history, let window = table.window, event.window === window else { return false }
        switch event.type {
        case .leftMouseDown: return click(event, in: table, window: window, viewModel: viewModel)
        case .keyDown: return key(event, in: table, window: window, viewModel: viewModel)
        default: return false
        }
    }

    private func click(_ event: NSEvent, in table: NSTableView, window: NSWindow, viewModel: RepositoryViewModel) -> Bool {
        let action = HistoryInput.pointer(event.modifierFlags, clickCount: event.clickCount, isMultiSelection: viewModel.isMultiCommitSelection)
        guard action != .pass, let hash = hash(at: event, in: table, window: window, viewModel: viewModel) else { return false }
        switch action {
        case .extend:
            window.makeFirstResponder(table)
            viewModel.clickCommit(hash, extending: true)
            return true
        case .toggle:
            window.makeFirstResponder(table)
            viewModel.clickCommit(hash, toggling: true)
            return true
        case .collapse:
            viewModel.clickCommit(hash)
            return false
        case .pass:
            return false
        }
    }

    private func key(_ event: NSEvent, in table: NSTableView, window: NSWindow, viewModel: RepositoryViewModel) -> Bool {
        guard window.firstResponder === table else { return false }
        switch HistoryInput.key(event.charactersIgnoringModifiers, modifiers: event.modifierFlags) {
        case .selectAll:
            viewModel.selectAllCommits()
            return true
        case .copy:
            guard !viewModel.selectedCommits.isEmpty else { return false }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(viewModel.selectedCommitSHAs, forType: .string)
            return true
        case .preview:
            guard viewModel.selectedCommit != nil || viewModel.isPreviewingCommit else { return false }
            viewModel.toggleCommitPreview()
            return true
        case .pass:
            return false
        }
    }

    private func hash(at event: NSEvent, in table: NSTableView, window: NSWindow, viewModel: RepositoryViewModel) -> String? {
        guard let content = window.contentView, let frame = content.superview,
              let hit = content.hitTest(frame.convert(event.locationInWindow, from: nil)), hit.isDescendant(of: table) else { return nil }
        let row = table.row(at: table.convert(event.locationInWindow, from: nil))
        let rows = viewModel.visibleHistoryRows
        return rows.indices.contains(row) ? rows[row].id : nil
    }

    isolated deinit {
        detach()
    }
}

struct HistoryTableHook: NSViewRepresentable {
    let link: HistoryTableLink

    func makeNSView(context: Context) -> HookView {
        HookView(link: link)
    }

    func updateNSView(_ view: HookView, context: Context) {
        view.link = link
        view.apply()
    }

    final class HookView: NSView {
        var link: HistoryTableLink

        init(link: HistoryTableLink) {
            self.link = link
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
            DispatchQueue.main.async { [weak self] in self?.apply() }
        }

        override func layout() {
            super.layout()
            apply()
        }

        func apply() {
            var ancestor = superview
            while let view = ancestor, !(view is NSTableView) { ancestor = view.superview }
            guard let table = ancestor as? NSTableView else { return }
            if table.selectionHighlightStyle != .none { table.selectionHighlightStyle = .none }
            link.attach(table)
        }
    }
}
