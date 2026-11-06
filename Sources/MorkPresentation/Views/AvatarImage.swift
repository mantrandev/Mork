import AppKit
import CoreGraphics
import ImageIO
import SwiftUI

public enum AvatarDecoder {
    public static func decode(_ data: Data, maxPixelSize: Int) async -> CGImage? {
        await Task.detached(priority: .utility) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            let options = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
            ] as CFDictionary
            return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
        }.value
    }
}

struct AvatarImage: View {
    let id: String
    let size: CGFloat
    let load: @MainActor () async -> Data?
    @Environment(\.displayScale) private var displayScale
    @State private var image: CGImage?

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: displayScale)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(Palette.Text.secondary.color)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: id) {
            guard let data = await load() else { return }
            image = await AvatarDecoder.decode(data, maxPixelSize: Int((size * displayScale).rounded(.up)))
        }
    }
}

public struct AppKitClipboard: ClipboardProtocol {
    public init() {}

    @MainActor
    public func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
