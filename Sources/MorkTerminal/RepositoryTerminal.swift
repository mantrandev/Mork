import AppKit
import SwiftTerm
import SwiftUI

public struct RepositoryTerminal: NSViewRepresentable {
    public let directory: URL
    public let focusRequest: Int

    public init(directory: URL, focusRequest: Int) {
        self.directory = directory
        self.focusRequest = focusRequest
    }

    public func makeNSView(context: Context) -> ShellTerminalView {
        ShellTerminalView(directory: directory)
    }

    public func updateNSView(_ view: ShellTerminalView, context: Context) {
        if view.directory != directory { view.restart(in: directory) }
        guard focusRequest != context.coordinator.appliedFocusRequest else { return }
        context.coordinator.appliedFocusRequest = focusRequest
        view.requestFocus()
    }

    public static func dismantleNSView(_ view: ShellTerminalView, coordinator: Coordinator) {
        view.session.terminate()
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public final class Coordinator {
        var appliedFocusRequest = 0
    }
}

public final class ShellTerminalView: TerminalView, @preconcurrency TerminalViewDelegate {
    public static let accessibilityIdentifier = "terminal.view"

    public private(set) var directory: URL
    let session = ShellSession()
    private var wantsFocus = false

    init(directory: URL) {
        self.directory = directory
        super.init(frame: CGRect(x: 0, y: 0, width: 600, height: 200), font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular))
        terminalDelegate = self
        configureNativeColors()
        setAccessibilityIdentifier(Self.accessibilityIdentifier)
        session.onOutput = { [weak self] bytes in self?.feed(byteArray: bytes) }
        session.onExit = { [weak self] code in
            self?.feed(text: "\r\n[Shell exited\(code.map { " with code \($0)" } ?? "")]\r\n")
        }
        session.windowSize = { [weak self] in
            guard let terminal = self?.getTerminal() else { return winsize() }
            return winsize(ws_row: UInt16(clamping: terminal.rows), ws_col: UInt16(clamping: terminal.cols), ws_xpixel: 0, ws_ypixel: 0)
        }
        session.start(.login(in: directory))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func restart(in directory: URL) {
        session.terminate()
        self.directory = directory
        session.start(.login(in: directory))
    }

    func requestFocus() {
        wantsFocus = true
        focusIfPossible()
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        focusIfPossible()
    }

    public override func isAccessibilityElement() -> Bool {
        true
    }

    public override func accessibilityRole() -> NSAccessibility.Role? {
        .textArea
    }

    public override func accessibilityLabel() -> String? {
        "Terminal"
    }

    public override func accessibilityValue() -> Any? {
        let terminal = getTerminal()
        return (0..<terminal.rows)
            .compactMap { terminal.getLine(row: $0)?.translateToString(trimRight: true) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public override func isAccessibilityFocused() -> Bool {
        window?.firstResponder === self
    }

    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        configureNativeColors()
    }

    private func focusIfPossible() {
        guard wantsFocus, let window else { return }
        wantsFocus = false
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            window.makeFirstResponder(self)
        }
    }

    public func send(source: TerminalView, data: ArraySlice<UInt8>) {
        session.send(data)
    }

    public func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        session.resize(columns: newCols, rows: newRows)
    }

    public func clipboardCopy(source: TerminalView, content: Data) {
        guard let text = String(data: content, encoding: .utf8) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    public func clipboardRead(source: TerminalView) -> Data? {
        NSPasteboard.general.string(forType: .string).map { Data($0.utf8) }
    }

    public func setTerminalTitle(source: TerminalView, title: String) {}
    public func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    public func scrolled(source: TerminalView, position: Double) {}
    public func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
}
