import MorkDomain
import CoreGraphics
import SwiftUI

struct AuthorAvatarImage: View {
    enum Style {
        case header
        case author
        case row

        var size: CGFloat {
            switch self {
            case .header: Metrics.Icon.avatar
            case .author: Metrics.CommitDetails.authorAvatar
            case .row: Metrics.Icon.rowAvatar
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .header: Metrics.Radius.control
            case .author: Metrics.Radius.card
            case .row: Metrics.Radius.badge
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .header: Metrics.FontSize.title
            case .author: Metrics.FontSize.heading
            case .row: Metrics.FontSize.avatarInitials
            }
        }
    }

    private struct Loaded {
        let email: String
        let pixelSize: Int
        let image: CGImage
    }

    let name: String
    let email: String
    let style: Style
    @Environment(AuthorAvatarImageCache.self) private var avatars: AuthorAvatarImageCache?
    @Environment(\.displayScale) private var displayScale
    @State private var loaded: Loaded?

    var body: some View {
        let image = currentImage
        AuthorInitials(name: name, fontSize: style.fontSize)
            .frame(width: style.size, height: style.size)
            .overlay {
                if let image {
                    Image(decorative: image, scale: displayScale)
                        .resizable()
                        .interpolation(.high)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
            .accessibilityHidden(true)
            .task(id: image == nil ? requestKey : nil) { await load() }
    }

    private var pixelSize: Int {
        Int((style.size * displayScale).rounded(.up))
    }

    private var isEnabled: Bool {
        avatars?.isEnabled == true
    }

    private var currentImage: CGImage? {
        guard isEnabled, let avatars else { return nil }
        if let loaded, loaded.email == email, loaded.pixelSize == pixelSize { return loaded.image }
        return avatars.cachedImage(for: email, pixelSize: pixelSize)
    }

    private var requestKey: String? {
        guard isEnabled, let avatars, !email.isEmpty, !avatars.hasFailed(email) else { return nil }
        return "\(pixelSize) \(email)"
    }

    private func load() async {
        guard requestKey != nil, currentImage == nil, let avatars else { return }
        let email = email
        let pixelSize = pixelSize
        guard let image = await avatars.image(for: email, pixelSize: pixelSize), !Task.isCancelled else { return }
        loaded = Loaded(email: email, pixelSize: pixelSize, image: image)
    }
}

private struct AuthorInitials: View {
    let name: String
    let fontSize: CGFloat

    var body: some View {
        Text(initials)
            .font(.system(size: fontSize, weight: .bold))
            .foregroundStyle(Palette.Status.onFill.color)
            .lineLimit(1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AuthorAvatarPalette.color(for: name))
    }

    private var initials: String {
        let words = name.split(separator: " ").prefix(2)
        let letters = words.compactMap(\.first).map { String($0).uppercased() }.joined()
        return letters.isEmpty ? "?" : letters
    }
}

enum AuthorAvatarPalette {
    static func index(for name: String) -> Int {
        let seed = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return seed % CommitGraphPalette.entries.count
    }

    static func token(for name: String) -> ColorToken {
        CommitGraphPalette.entries[index(for: name)]
    }

    static func color(for name: String) -> Color {
        CommitGraphPalette.colors[index(for: name)]
    }
}
