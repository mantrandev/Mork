import AppKit
import MorkDomain
import SwiftUI

struct ConflictResultEditor: NSViewRepresentable {
    let text: String
    let revision: Int
    let tints: ConflictResultTints
    let documentVersion: Int
    let isEditable: Bool
    let onChange: @MainActor (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = false
        container.lineFragmentPadding = Metrics.Spacing.s
        layoutManager.addTextContainer(container)

        let textView = ConflictResultTextView(frame: .zero, textContainer: container)
        textView.configure()
        textView.delegate = context.coordinator
        storage.delegate = context.coordinator

        let scrollView = NSScrollView()
        scrollView.clipsToBounds = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        let ruler = ConflictLineNumberRuler(textView: textView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        context.coordinator.textView = textView
        context.coordinator.load(text, revision: revision, version: documentVersion)
        context.coordinator.apply(tints, revision: revision)
        textView.isEditable = isEditable
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onChange = onChange
        coordinator.textView?.isEditable = isEditable
        if coordinator.version != documentVersion {
            coordinator.load(text, revision: revision, version: documentVersion)
        } else if coordinator.revision != revision {
            coordinator.replace(with: text, revision: revision)
        }
        coordinator.apply(tints, revision: revision)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        var onChange: @MainActor (String) -> Void
        weak var textView: ConflictResultTextView?
        private(set) var version = -1
        private(set) var revision = -1
        private var text = ""
        private var appliedTints = ConflictResultTints(revision: -1)
        private var isApplying = false

        init(onChange: @escaping @MainActor (String) -> Void) {
            self.onChange = onChange
        }

        func load(_ text: String, revision: Int, version: Int) {
            guard let textView, let storage = textView.textStorage else { return }
            isApplying = true
            storage.setAttributedString(NSAttributedString(string: text, attributes: textView.typingAttributes))
            isApplying = false
            textView.lines = ConflictLineStarts(storage.string as NSString)
            textView.undoManager?.removeAllActions()
            self.text = text
            self.revision = revision
            self.version = version
            appliedTints = ConflictResultTints(revision: -1)
            textView.refreshRuler()
        }

        func replace(with newText: String, revision: Int) {
            guard let textView, newText != text else {
                self.revision = revision
                return
            }
            let old = text as NSString
            let new = newText as NSString
            let prefix = Self.commonPrefix(old, new)
            let suffix = Self.commonSuffix(old, new, limit: min(old.length, new.length) - prefix)
            let range = NSRange(location: prefix, length: old.length - prefix - suffix)
            let replacement = new.substring(with: NSRange(location: prefix, length: new.length - prefix - suffix))
            isApplying = true
            textView.breakUndoCoalescing()
            if textView.shouldChangeText(in: range, replacementString: replacement) {
                textView.textStorage?.replaceCharacters(in: range, with: replacement)
                textView.didChangeText()
            }
            textView.breakUndoCoalescing()
            isApplying = false
            let changed = NSRange(location: prefix, length: (replacement as NSString).length)
            textView.setSelectedRange(NSRange(location: NSMaxRange(changed), length: 0))
            textView.scrollRangeToVisible(changed)
            textView.window?.makeFirstResponder(textView)
            text = newText
            self.revision = revision
        }

        func apply(_ tints: ConflictResultTints, revision: Int) {
            guard tints.revision == revision, tints.revision == self.revision, tints != appliedTints,
                  let textView, let storage = textView.textStorage else { return }
            storage.beginEditing()
            for run in tints.runs where NSMaxRange(run.range) <= storage.length {
                var effective = NSRange()
                let current = storage.attribute(.conflictOrigin, at: run.range.location, longestEffectiveRange: &effective, in: run.range) as? Int
                if current == run.origin.code, effective == run.range { continue }
                storage.addAttribute(.conflictOrigin, value: run.origin.code, range: run.range)
            }
            storage.endEditing()
            appliedTints = tints
            textView.needsDisplay = true
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplying, let textView else { return }
            let string = textView.string
            text = string
            onChange(string)
        }

        nonisolated func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
            guard editedMask.contains(.editedCharacters) else { return }
            nonisolated(unsafe) let storage = textStorage
            MainActor.assumeIsolated {
                if editedRange.length > 0 {
                    storage.addAttribute(.conflictOrigin, value: ConflictLineOrigin.edited.code, range: editedRange)
                }
                textView?.lines.edited(editedRange, changeInLength: delta, in: storage.string as NSString)
                textView?.refreshRuler()
            }
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            textView.isEditable || isApplying
        }

        func undoManager(for view: NSTextView) -> UndoManager? {
            (view as? ConflictResultTextView)?.ownUndoManager
        }

        private static func commonPrefix(_ old: NSString, _ new: NSString) -> Int {
            let limit = min(old.length, new.length)
            var index = 0
            while index < limit, old.character(at: index) == new.character(at: index) {
                index += 1
            }
            return index
        }

        private static func commonSuffix(_ old: NSString, _ new: NSString, limit: Int) -> Int {
            var count = 0
            while count < limit, old.character(at: old.length - 1 - count) == new.character(at: new.length - 1 - count) {
                count += 1
            }
            return count
        }
    }
}

extension NSAttributedString.Key {
    static let conflictOrigin = NSAttributedString.Key("dev.mantrandev.mork.conflictOrigin")
}

extension ConflictLineOrigin {
    static let all: [ConflictLineOrigin] = [.common, .ours, .theirs, .unresolved, .edited]

    var code: Int { Self.all.firstIndex(of: self) ?? 0 }

    init(code: Int?) {
        self = code.flatMap { Self.all.indices.contains($0) ? Self.all[$0] : nil } ?? .common
    }

    var tint: ColorToken? {
        switch self {
        case .common: nil
        case .ours: Palette.Status.modified.tint
        case .theirs: Palette.Status.renamed.tint
        case .unresolved: Palette.Status.conflict.tint
        case .edited: Palette.Diff.editedLine
        }
    }
}

final class ConflictResultTextView: NSTextView {
    static let font = NSFont.monospacedSystemFont(ofSize: Metrics.FontSize.body, weight: .regular)

    let ownUndoManager = UndoManager()
    var lines = ConflictLineStarts("" as NSString)

    func configure() {
        isRichText = false
        importsGraphics = false
        allowsUndo = true
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isContinuousSpellCheckingEnabled = false
        isGrammarCheckingEnabled = false
        smartInsertDeleteEnabled = false
        usesFindBar = true
        isIncrementalSearchingEnabled = true
        isHorizontallyResizable = true
        isVerticallyResizable = true
        autoresizingMask = [.width, .height]
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textContainerInset = NSSize(width: 0, height: Metrics.Spacing.xs)
        drawsBackground = true
        backgroundColor = Palette.Surface.window.nsColor
        insertionPointColor = Palette.Text.primary.nsColor
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = Metrics.Conflict.lineHeight
        paragraph.maximumLineHeight = Metrics.Conflict.lineHeight
        defaultParagraphStyle = paragraph
        typingAttributes = [.font: Self.font, .foregroundColor: Palette.Text.primary.nsColor, .paragraphStyle: paragraph]
        setAccessibilityIdentifier("conflict.result.editor")
    }

    @objc func undo(_ sender: Any?) {
        ownUndoManager.undo()
    }

    @objc func redo(_ sender: Any?) {
        ownUndoManager.redo()
    }

    override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        switch item.action {
        case #selector(undo(_:)): ownUndoManager.canUndo
        case #selector(redo(_:)): ownUndoManager.canRedo
        default: super.validateUserInterfaceItem(item)
        }
    }

    func refreshRuler() {
        guard let ruler = enclosingScrollView?.verticalRulerView as? ConflictLineNumberRuler else { return }
        ruler.updateThickness()
        ruler.needsDisplay = true
    }

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        guard let layoutManager, let textContainer, let storage = textStorage, storage.length > 0 else { return }
        let inset = textContainerOrigin
        let glyphs = layoutManager.glyphRange(forBoundingRect: rect.offsetBy(dx: -inset.x, dy: -inset.y), in: textContainer)
        let characters = layoutManager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
        var line = lines.line(containing: characters.location)
        while line < lines.count {
            let start = lines.starts[line]
            guard start < storage.length, start <= NSMaxRange(characters) else { break }
            let end = line + 1 < lines.count ? lines.starts[line + 1] : storage.length
            let range = NSRange(location: start, length: end - start)
            if let tint = origin(of: range, in: storage).tint {
                let lineGlyphs = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                if lineGlyphs.length > 0 {
                    let first = layoutManager.lineFragmentRect(forGlyphAt: lineGlyphs.location, effectiveRange: nil)
                    let last = layoutManager.lineFragmentRect(forGlyphAt: NSMaxRange(lineGlyphs) - 1, effectiveRange: nil)
                    tint.nsColor.setFill()
                    NSRect(x: rect.minX, y: first.minY + inset.y, width: rect.width, height: last.maxY - first.minY).fill()
                }
            }
            line += 1
        }
    }

    private func origin(of range: NSRange, in storage: NSTextStorage) -> ConflictLineOrigin {
        var first: ConflictLineOrigin?
        var isEdited = false
        storage.enumerateAttribute(.conflictOrigin, in: range) { value, _, stop in
            let origin = ConflictLineOrigin(code: value as? Int)
            if first == nil { first = origin }
            if origin == .edited {
                isEdited = true
                stop.pointee = true
            }
        }
        return isEdited ? .edited : first ?? .common
    }
}

final class ConflictLineNumberRuler: NSRulerView {
    private static let font = NSFont.monospacedDigitSystemFont(ofSize: Metrics.FontSize.caption, weight: .regular)
    private static let digitWidth = ("0" as NSString).size(withAttributes: [.font: font]).width

    private weak var textView: ConflictResultTextView?
    private var digits = 0

    init(textView: ConflictResultTextView) {
        self.textView = textView
        super.init(scrollView: nil, orientation: .verticalRuler)
        clientView = textView
        clipsToBounds = true
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Line numbers")
        setAccessibilityIdentifier("conflict.result.gutter")
        updateThickness()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool { true }

    func updateThickness() {
        let needed = max(String(textView?.lines.count ?? 1).count, Metrics.Conflict.gutterMinimumDigits)
        guard needed != digits else { return }
        digits = needed
        ruleThickness = (CGFloat(needed) * Self.digitWidth + Metrics.Spacing.s * 2).rounded(.up)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        Palette.Diff.gutter.nsColor.setFill()
        bounds.intersection(rect).fill()
        guard let textView, let layoutManager = textView.layoutManager, let textContainer = textView.textContainer,
              let storage = textView.textStorage else { return }
        let lines = textView.lines
        let visible = textView.visibleRect
        let origin = textView.textContainerOrigin
        let glyphs = layoutManager.glyphRange(forBoundingRect: visible.offsetBy(dx: -origin.x, dy: -origin.y), in: textContainer)
        let characters = layoutManager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
        let attributes: [NSAttributedString.Key: Any] = [.font: Self.font, .foregroundColor: Palette.Text.tertiary.nsColor]
        let offset = convert(NSPoint.zero, from: textView).y
        var line = lines.line(containing: characters.location)
        while line < lines.count {
            let start = lines.starts[line]
            guard start <= NSMaxRange(characters) else { break }
            let lineRect: NSRect
            if start < storage.length {
                let glyph = layoutManager.glyphIndexForCharacter(at: start)
                lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            } else if start == 0 || layoutManager.extraLineFragmentRect.height > 0 {
                lineRect = layoutManager.extraLineFragmentRect
            } else {
                break
            }
            let label = "\(line + 1)" as NSString
            let size = label.size(withAttributes: attributes)
            let y = lineRect.minY + origin.y + offset + (lineRect.height - size.height) / 2
            label.draw(at: NSPoint(x: ruleThickness - Metrics.Spacing.s - size.width, y: y), withAttributes: attributes)
            line += 1
        }
    }
}
