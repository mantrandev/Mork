import CoreGraphics
import MorkDomain
import Foundation
import ImageIO

public final class DecodedImage: @unchecked Sendable, Equatable {
    public let image: CGImage

    init(_ image: CGImage) {
        self.image = image
    }

    public static func == (lhs: DecodedImage, rhs: DecodedImage) -> Bool {
        lhs === rhs
    }
}

public struct ImageSidePreview: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case missing
        case tooLarge
        case unreadable
        case image(DecodedImage)
    }

    public let kind: Kind
    public let caption: String

    public var image: DecodedImage? {
        if case let .image(image) = kind { image } else { nil }
    }
}

public struct ImageDiffPreview: Equatable, Sendable {
    public let old: ImageSidePreview
    public let new: ImageSidePreview

    public var canOverlay: Bool { old.image != nil && new.image != nil }
}

enum ImageDecoder {
    static let maxPixelSize = 4096

    static func preview(_ diff: ImageDiff, path: String) -> ImageDiffPreview {
        let isPDF = path.lowercased().hasSuffix(".pdf")
        return ImageDiffPreview(
            old: preview(diff.old, isPDF: isPDF, missing: "Not in the old version"),
            new: preview(diff.new, isPDF: isPDF, missing: "Deleted")
        )
    }

    static func preview(_ blob: ImageBlob, isPDF: Bool, missing: String) -> ImageSidePreview {
        switch blob {
        case .missing:
            return ImageSidePreview(kind: .missing, caption: missing)
        case let .tooLarge(count):
            return ImageSidePreview(kind: .tooLarge, caption: "Too large to preview (\(size(count)))")
        case let .loaded(data):
            let decoded = isPDF ? pdf(data) : bitmap(data)
            guard let decoded else { return ImageSidePreview(kind: .unreadable, caption: "Cannot decode this image (\(size(data.count)))") }
            return ImageSidePreview(kind: .image(DecodedImage(decoded.image)), caption: "\(decoded.dimensions) · \(size(data.count))")
        }
    }

    static func size(_ count: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }

    private static func bitmap(_ data: Data) -> (image: CGImage, dimensions: String)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else { return nil }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let width = (properties?[kCGImagePropertyPixelWidth] as? Int) ?? image.width
        let height = (properties?[kCGImagePropertyPixelHeight] as? Int) ?? image.height
        return (image, "\(width) × \(height) px")
    }

    private static func pdf(_ data: Data) -> (image: CGImage, dimensions: String)? {
        guard let provider = CGDataProvider(data: data as CFData), let document = CGPDFDocument(provider), let page = document.page(at: 1) else { return nil }
        let box = page.getBoxRect(.mediaBox)
        guard box.width > 0, box.height > 0 else { return nil }
        let scale = min(2, CGFloat(maxPixelSize) / max(box.width, box.height))
        let width = Int(box.width * scale)
        let height = Int(box.height * scale)
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -box.minX, y: -box.minY)
        context.drawPDFPage(page)
        guard let image = context.makeImage() else { return nil }
        let pages = document.numberOfPages
        return (image, "PDF page 1 of \(pages), \(Int(box.width)) × \(Int(box.height)) pt")
    }
}
