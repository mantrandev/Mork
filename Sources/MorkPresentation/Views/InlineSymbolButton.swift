import AppKit

@MainActor
enum TintedSymbolImage {
    private struct Key: Hashable {
        let name: String
        let tint: ColorToken
        let isDark: Bool
        let scale: CGFloat
    }

    private static var images: [Key: CGImage] = [:]

    static func image(_ name: String, tint: ColorToken, isDark: Bool, scale: CGFloat) -> CGImage? {
        let key = Key(name: name, tint: tint, isDark: isDark, scale: scale)
        if let image = images[key] { return image }
        let color = (isDark ? tint.dark : tint.light).nsColor
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [color])) else { return nil }
        let size = symbol.size
        let width = Int((size.width * scale).rounded(.up))
        let height = Int((size.height * scale).rounded(.up))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.scaleBy(x: scale, y: scale)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        symbol.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        guard let image = context.makeImage() else { return nil }
        images[key] = image
        return image
    }
}

final class InlineSymbolButton: NSControl {
    private static let pressedAlpha: CGFloat = 0.5

    var symbolName = "" {
        didSet { if symbolName != oldValue { refresh() } }
    }

    var tint = Palette.Accent.text {
        didSet { if tint != oldValue { refresh() } }
    }

    var onPress: () -> Void = {}

    private var isPressed = false {
        didSet { alphaValue = isPressed ? Self.pressedAlpha : 1 }
    }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layerContentsRedrawPolicy = .never
        layer?.contentsGravity = .center
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        refresh()
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let image = currentImage, let context = NSGraphicsContext.current?.cgContext else { return }
        let size = NSSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
        let origin = NSPoint(x: ((bounds.width - size.width) / 2).rounded(), y: ((bounds.height - size.height) / 2).rounded())
        context.draw(image, in: NSRect(origin: origin, size: size))
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

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
    }

    override func mouseDragged(with event: NSEvent) {
        isPressed = contains(event)
    }

    override func mouseUp(with event: NSEvent) {
        let fires = isPressed && contains(event)
        isPressed = false
        if fires { onPress() }
    }

    override func performClick(_ sender: Any?) {
        onPress()
    }

    override func accessibilityPerformPress() -> Bool {
        onPress()
        return true
    }

    private func contains(_ event: NSEvent) -> Bool {
        bounds.contains(convert(event.locationInWindow, from: nil))
    }

    private var scale: CGFloat {
        window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }

    private var currentImage: CGImage? {
        guard !symbolName.isEmpty else { return nil }
        let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return TintedSymbolImage.image(symbolName, tint: tint, isDark: isDark, scale: scale)
    }

    private func refresh() {
        layer?.contentsScale = scale
        layer?.contents = currentImage
    }
}
