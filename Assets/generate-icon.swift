import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let canvas: CGFloat = 1024

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func squircle(in rect: CGRect, exponent: CGFloat = 5) -> CGPath {
    let path = CGMutablePath()
    let steps = 720
    let a = rect.width / 2
    let b = rect.height / 2
    for step in 0..<steps {
        let t = CGFloat(step) / CGFloat(steps) * 2 * .pi
        let c = cos(t)
        let s = sin(t)
        let x = rect.midX + a * (c < 0 ? -1 : 1) * pow(abs(c), 2 / exponent)
        let y = rect.midY + b * (s < 0 ? -1 : 1) * pow(abs(s), 2 / exponent)
        if step == 0 {
            path.move(to: CGPoint(x: x, y: y))
        } else {
            path.addLine(to: CGPoint(x: x, y: y))
        }
    }
    path.closeSubpath()
    return path
}

func makeContext(size: Int) -> CGContext {
    let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let scale = CGFloat(size) / canvas
    context.translateBy(x: 0, y: CGFloat(size))
    context.scaleBy(x: scale, y: -scale)
    context.interpolationQuality = .high
    context.setShouldAntialias(true)
    return context
}

let constellationPoints = [
    CGPoint(x: 262, y: 760),
    CGPoint(x: 322, y: 300),
    CGPoint(x: 512, y: 590),
    CGPoint(x: 702, y: 300),
    CGPoint(x: 762, y: 760)
]
let headIndex = 3
let dustPoints: [(point: CGPoint, radius: CGFloat)] = [
    (CGPoint(x: 216, y: 232), 9),
    (CGPoint(x: 512, y: 230), 11),
    (CGPoint(x: 840, y: 500), 9),
    (CGPoint(x: 196, y: 540), 8),
    (CGPoint(x: 600, y: 830), 9)
]

func circle(at center: CGPoint, radius: CGFloat) -> CGRect {
    CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
}

func fillStar(_ context: CGContext, at center: CGPoint, radius: CGFloat, top: UInt32, bottom: UInt32) {
    context.saveGState()
    context.addEllipse(in: circle(at: center, radius: radius))
    context.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [color(top), color(bottom)] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(gradient, start: CGPoint(x: center.x, y: center.y - radius), end: CGPoint(x: center.x, y: center.y + radius), options: [])
    context.restoreGState()
}

func constellation(size: Int, fullBleed: Bool = false) -> CGImage {
    let context = makeContext(size: size)
    let compact = size <= 32
    if fullBleed {
        context.translateBy(x: 512, y: 512)
        context.scaleBy(x: canvas / 824, y: canvas / 824)
        context.translateBy(x: -512, y: -512)
    }

    if !compact {
        context.setFillColor(color(0xF4F6FB, alpha: 0.5))
        for dust in dustPoints {
            context.fillEllipse(in: circle(at: dust.point, radius: dust.radius))
        }
    }

    context.addLines(between: constellationPoints)
    context.setStrokeColor(color(0x8FA3CC))
    context.setLineWidth(compact ? 64 : 40)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.strokePath()

    for (index, point) in constellationPoints.enumerated() where index != headIndex {
        fillStar(context, at: point, radius: compact ? 78 : 58, top: 0xF4F6FB, bottom: 0xA9B6D3)
    }

    let head = constellationPoints[headIndex]
    if !compact {
        context.setFillColor(color(0x3DD6A8, alpha: 0.22))
        context.fillEllipse(in: circle(at: head, radius: 112))
    }
    fillStar(context, at: head, radius: compact ? 92 : 72, top: 0x6FE8C4, bottom: 0x2BBF93)
    return context.makeImage()!
}

func icon(size: Int) -> CGImage {
    let context = makeContext(size: size)
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = squircle(in: body)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: color(0x000000, alpha: 0.35))
    context.addPath(shape)
    context.setFillColor(color(0x0E1424))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(shape)
    context.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [color(0x1D2740), color(0x070A12)] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])
    context.restoreGState()

    context.saveGState()
    context.translateBy(x: 0, y: canvas)
    context.scaleBy(x: 1, y: -1)
    context.draw(constellation(size: size), in: CGRect(x: 0, y: 0, width: canvas, height: canvas))
    context.restoreGState()

    return context.makeImage()!
}

func badge(_ label: String, fill: UInt32, size: Int) -> CGImage {
    let context = makeContext(size: size)
    let pill = CGRect(x: 262, y: 716, width: 500, height: 188)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 8), blur: 18, color: color(0x000000, alpha: 0.35))
    context.addPath(CGPath(roundedRect: pill, cornerWidth: 94, cornerHeight: 94, transform: nil))
    context.setFillColor(color(fill))
    context.fillPath()
    context.restoreGState()
    context.addPath(CGPath(roundedRect: pill.insetBy(dx: 6, dy: 6), cornerWidth: 88, cornerHeight: 88, transform: nil))
    context.setStrokeColor(color(0xFFFFFF, alpha: 0.9))
    context.setLineWidth(12)
    context.strokePath()
    let font = CTFontCreateWithName("SFProRounded-Heavy" as CFString, 136, nil)
    let text = NSAttributedString(string: label, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color(0xFFFFFF),
        NSAttributedString.Key(kCTKernAttributeName as String): 6
    ])
    let line = CTLineCreateWithAttributedString(text)
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
    context.textPosition = CGPoint(x: pill.midX - bounds.midX, y: pill.midY + bounds.midY)
    CTLineDraw(line, context)
    return context.makeImage()!
}

func badged(_ base: CGImage, _ label: String, fill: UInt32, size: Int) -> CGImage {
    let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    context.draw(base, in: rect)
    context.draw(badge(label, fill: fill, size: size), in: rect)
    return context.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("Failed to write \(url.path)")
    }
}

let assets = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Assets")

let badgeGroup = """
        {
          "layers" : [
            {
              "image-name" : "badge.png",
              "name" : "badge"
            }
          ],
          "shadow" : {
            "kind" : "none",
            "opacity" : 0.5
          },
          "translucency" : {
            "enabled" : false,
            "value" : 0.5
          }
        },

    """

func manifest(labelled: Bool) -> String {
    """
    {
      "fill" : {
        "linear-gradient" : [
          "srgb:0.11373,0.15294,0.25098,1.00000",
          "srgb:0.02745,0.03922,0.07059,1.00000"
        ]
      },
      "groups" : [
    \(labelled ? badgeGroup : "")    {
          "layers" : [
            {
              "image-name" : "constellation.png",
              "name" : "constellation"
            }
          ],
          "shadow" : {
            "kind" : "neutral",
            "opacity" : 0.5
          },
          "translucency" : {
            "enabled" : false,
            "value" : 0.5
          }
        }
      ],
      "supported-platforms" : {
        "squares" : [
          "macOS"
        ]
      }
    }

    """
}

let variants: [(name: String, label: (text: String, fill: UInt32)?)] = [
    ("AppIcon", nil),
    ("AppIcon-DEV", ("DEV", 0xF97316))
]

for variant in variants {
    let iconset = assets.appendingPathComponent("\(variant.name).iconset")
    try? FileManager.default.removeItem(at: iconset)
    try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
    for points in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let pixels = points * scale
            let suffix = scale == 1 ? "" : "@2x"
            let image = variant.label.map { badged(icon(size: pixels), $0.text, fill: $0.fill, size: pixels) } ?? icon(size: pixels)
            writePNG(image, to: iconset.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
        }
    }

    let composer = assets.appendingPathComponent("\(variant.name).icon")
    let composerAssets = composer.appendingPathComponent("Assets")
    try? FileManager.default.removeItem(at: composer)
    try FileManager.default.createDirectory(at: composerAssets, withIntermediateDirectories: true)
    writePNG(constellation(size: 1024, fullBleed: true), to: composerAssets.appendingPathComponent("constellation.png"))
    if let label = variant.label {
        writePNG(badge(label.text, fill: label.fill, size: 1024), to: composerAssets.appendingPathComponent("badge.png"))
    }
    try Data(manifest(labelled: variant.label != nil).utf8).write(to: composer.appendingPathComponent("icon.json"))
}
