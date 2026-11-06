import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct StatusBadge: View {
    let letter: Character
    let color: Color

    var body: some View {
        Text(String(letter))
            .font(Metrics.Font.monoBadge)
            .foregroundStyle(Palette.Status.onFill.color)
            .frame(width: Metrics.Icon.column, height: Metrics.Icon.column)
            .background(color, in: RoundedRectangle(cornerRadius: Metrics.Radius.badge, style: .continuous))
    }

    static func color(for letter: Character) -> Color {
        Palette.Status.status(for: letter).ink.color
    }
}

struct FileIcon: View {
    let path: String

    var body: some View {
        Image(nsImage: FileIconCache.icon(forExtension: FilePathParts(path).fileExtension))
            .resizable()
            .interpolation(.high)
            .frame(width: Metrics.Icon.column, height: Metrics.Icon.column)
            .accessibilityHidden(true)
    }
}

@MainActor
enum FileIconCache {
    private static var icons: [String: NSImage] = [:]

    static func icon(forExtension fileExtension: String) -> NSImage {
        let key = fileExtension.lowercased()
        if let icon = icons[key] { return icon }
        let type = key.isEmpty ? UTType.data : (UTType(filenameExtension: key) ?? .data)
        let source = NSWorkspace.shared.icon(for: type)
        let icon = PrerenderedImage.make(side: Metrics.Icon.column) { source.draw(in: $0) }
        icons[key] = icon
        return icon
    }
}

enum PrerenderedImage {
    static let scales = [1, 2]

    static func make(side: CGFloat, draw: (NSRect) -> Void) -> NSImage {
        let size = NSSize(width: side, height: side)
        let image = NSImage(size: size)
        for scale in scales {
            let pixels = Int(side) * scale
            guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { continue }
            bitmap.size = size
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
            NSGraphicsContext.current?.imageInterpolation = .high
            draw(NSRect(origin: .zero, size: size))
            NSGraphicsContext.restoreGraphicsState()
            image.addRepresentation(bitmap)
        }
        return image
    }
}

struct FilePathText: View {
    let path: String
    let originalPath: String?

    var body: some View {
        let parts = FilePathParts(path)
        let renamed = originalPath.map { Text("\($0) → ").foregroundStyle(Palette.Text.secondary.color) } ?? Text("")
        (renamed + Text(parts.directory).foregroundStyle(Palette.Text.secondary.color) + Text(parts.name).fontWeight(.semibold).foregroundStyle(Palette.Text.primary.color))
            .lineLimit(1)
            .truncationMode(.head)
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(FilePathParts.displayText(path: path, originalPath: originalPath))
    }
}

@MainActor
enum StatusBadgeImage {
    private struct Key: Hashable {
        let letter: Character
        let isDark: Bool
        let scale: CGFloat
    }

    private static var images: [Key: CGImage] = [:]

    static func image(for letter: Character, isDark: Bool, scale: CGFloat) -> CGImage {
        let key = Key(letter: letter, isDark: isDark, scale: scale)
        if let image = images[key] { return image }
        let image = render(letter, isDark: isDark, scale: scale)
        images[key] = image
        return image
    }

    private static func render(_ letter: Character, isDark: Bool, scale: CGFloat) -> CGImage {
        let side = Metrics.Icon.column
        let pixels = Int((side * scale).rounded())
        let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.scaleBy(x: scale, y: scale)
        let rect = CGRect(x: 0, y: 0, width: side, height: side)
        let ink = Palette.Status.status(for: letter).ink
        let onFill = Palette.Status.onFill
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        (isDark ? ink.dark : ink.light).nsColor.setFill()
        NSBezierPath(roundedRect: rect, xRadius: Metrics.Radius.badge, yRadius: Metrics.Radius.badge).fill()
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let text = NSAttributedString(string: String(letter), attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: Metrics.FontSize.label, weight: .bold),
            .foregroundColor: (isDark ? onFill.dark : onFill.light).nsColor,
            .paragraphStyle: paragraph,
        ])
        let height = ceil(text.size().height)
        text.draw(in: CGRect(x: 0, y: ((side - height) / 2).rounded(), width: side, height: height))
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()!
    }
}

final class StatusBadgeView: NSView {
    var letter: Character = " " {
        didSet { if letter != oldValue { refresh() } }
    }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layerContentsRedrawPolicy = .never
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        refresh()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.draw(currentImage, in: bounds)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refresh()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        refresh()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refresh()
    }

    private var scale: CGFloat {
        window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }

    private var currentImage: CGImage {
        let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return StatusBadgeImage.image(for: letter, isDark: isDark, scale: scale)
    }

    private func refresh() {
        layer?.contentsScale = scale
        layer?.contents = currentImage
    }
}

final class AccentSelectionRowView: NSTableRowView {
    static let identifier = NSUserInterfaceItemIdentifier("mork.accentSelectionRow")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = Self.identifier
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var isHovered = false {
        didSet { if isHovered != oldValue { needsDisplay = true } }
    }

    override var isEmphasized: Bool {
        get { false }
        set {}
    }

    override func drawBackground(in dirtyRect: NSRect) {
        guard isHovered, !isSelected else { return }
        Palette.Text.primary.nsColor.withAlphaComponent(Palette.Ink.hover).setFill()
        bounds.fill()
    }

    override func drawSelection(in dirtyRect: NSRect) {
        Palette.Accent.tint.nsColor.setFill()
        bounds.fill()
    }

    static func make(in tableView: NSTableView) -> AccentSelectionRowView {
        tableView.makeView(withIdentifier: identifier, owner: nil) as? AccentSelectionRowView ?? AccentSelectionRowView(frame: .zero)
    }
}
