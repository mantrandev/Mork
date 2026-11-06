import AppKit
import MorkDomain
import SwiftUI

struct ImageDiffView: View {
    @Bindable var session: ImageDiffViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Metrics.Spacing.m) {
                Picker("Mode", selection: $session.mode) {
                    ForEach(ImageDiffViewModel.Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .disabled(!session.canOverlay)
                .help(session.canOverlay ? "Compare the two versions" : "Swipe and onion skin need both versions")
                .accessibilityIdentifier("imageDiff.mode")
                switch session.visibleMode {
                case .sideBySide:
                    EmptyView()
                case .swipe:
                    Slider(value: $session.split, in: 0...1)
                        .frame(width: Metrics.ImageDiff.sliderWidth)
                        .accessibilityIdentifier("imageDiff.split")
                case .onionSkin:
                    Slider(value: $session.opacity, in: 0...1)
                        .frame(width: Metrics.ImageDiff.sliderWidth)
                        .accessibilityIdentifier("imageDiff.opacity")
                }
                Spacer()
                Text(session.sources.path)
                    .font(Metrics.Font.caption)
                    .foregroundStyle(Palette.Text.secondary.color)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, Metrics.Spacing.m)
            .frame(height: Metrics.Panel.header + Metrics.Spacing.s)
            Divider()
            content
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("imageDiff")
    }

    @ViewBuilder
    private var content: some View {
        switch session.state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .failed(message):
            EmptyStateView("Could Not Load Image", systemImage: "exclamationmark.triangle", message: message)
        case let .loaded(preview):
            switch session.visibleMode {
            case .sideBySide:
                HStack(spacing: 0) {
                    ImageSidePanel(title: "Old", side: preview.old, identifier: "imageDiff.old")
                    Divider()
                    ImageSidePanel(title: "New", side: preview.new, identifier: "imageDiff.new")
                }
            case .swipe:
                ImageOverlayPanel(preview: preview, mode: .swipe, split: session.split, opacity: session.opacity)
            case .onionSkin:
                ImageOverlayPanel(preview: preview, mode: .onionSkin, split: session.split, opacity: session.opacity)
            }
        }
    }
}

private struct ImageSidePanel: View {
    let title: String
    let side: ImageSidePreview
    let identifier: String

    var body: some View {
        VStack(spacing: Metrics.Spacing.s) {
            Text(title)
                .font(Metrics.Font.caption.weight(.semibold))
                .foregroundStyle(Palette.Text.secondary.color)
            ZStack {
                CheckerboardBackground()
                if let image = side.image {
                    Image(decorative: image.image, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .padding(Metrics.Spacing.s)
                } else {
                    Image(systemName: side.kind == .missing ? "photo.badge.plus" : "exclamationmark.triangle")
                        .font(.system(size: Metrics.Icon.avatar))
                        .foregroundStyle(Palette.Text.tertiary.color)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous))
            Text(side.caption)
                .font(Metrics.Font.caption.monospacedDigit())
                .foregroundStyle(Palette.Text.secondary.color)
                .accessibilityIdentifier("\(identifier).caption")
        }
        .padding(Metrics.Spacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}

private struct ImageOverlayPanel: View {
    let preview: ImageDiffPreview
    let mode: ImageDiffViewModel.Mode
    let split: Double
    let opacity: Double

    var body: some View {
        VStack(spacing: Metrics.Spacing.s) {
            ZStack {
                CheckerboardBackground()
                GeometryReader { proxy in
                    ZStack {
                        if let old = preview.old.image {
                            fitted(old)
                        }
                        if let new = preview.new.image {
                            fitted(new)
                                .opacity(mode == .onionSkin ? opacity : 1)
                                .mask(alignment: .leading) {
                                    Rectangle().frame(width: mode == .swipe ? proxy.size.width * split : proxy.size.width)
                                }
                        }
                        if mode == .swipe {
                            Rectangle()
                                .fill(Palette.Accent.fill.color)
                                .frame(width: Metrics.ImageDiff.handle)
                                .position(x: proxy.size.width * split, y: proxy.size.height / 2)
                                .frame(height: proxy.size.height)
                        }
                    }
                }
                .padding(Metrics.Spacing.s)
            }
            .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous))
            HStack {
                Text("Old: \(preview.old.caption)")
                Spacer()
                Text("New: \(preview.new.caption)")
            }
            .font(Metrics.Font.caption.monospacedDigit())
            .foregroundStyle(Palette.Text.secondary.color)
        }
        .padding(Metrics.Spacing.m)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(mode == .swipe ? "imageDiff.swipe" : "imageDiff.onionSkin")
    }

    private func fitted(_ image: DecodedImage) -> some View {
        Image(decorative: image.image, scale: 1)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CheckerboardBackground: View {
    var body: some View {
        Image(nsImage: Self.tile)
            .resizable(resizingMode: .tile)
            .accessibilityHidden(true)
    }

    private static let tile: NSImage = {
        let side = Metrics.ImageDiff.checker
        return NSImage(size: NSSize(width: side * 2, height: side * 2), flipped: false) { rect in
            Palette.Surface.window.nsColor.setFill()
            rect.fill()
            Palette.Surface.border.nsColor.setFill()
            NSRect(x: 0, y: 0, width: side, height: side).fill()
            NSRect(x: side, y: side, width: side, height: side).fill()
            return true
        }
    }()
}
