import AppKit
import MorkDomain
import SwiftUI

struct TreemapSheet: View {
    @Bindable var session: TreemapViewModel
    let repository: RepositoryViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Sheet.rowSpacing) {
            DialogHeader(kind: .notice, glyph: "square.grid.3x3", title: "Repository Treemap", message: "Every file at HEAD as a rectangle sized by its bytes. Mork only reads the tree.")
            CommandStrip(command: "git ls-tree -r -l -z HEAD", note: "read once")
            content
            DialogButtonRow {
                DialogConfirmButton(title: "Done", identifier: "treemap.done") { dismiss() }
            }
        }
        .padding(Metrics.Sheet.padding)
        .frame(width: Metrics.Sheet.largeWidth, height: Metrics.Sheet.largeHeight)
        .dialogSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("treemap.sheet")
    }

    @ViewBuilder
    private var content: some View {
        switch session.status {
        case .idle, .loading:
            ProgressView { Text("Reading file sizes at HEAD…").font(Metrics.Font.body).foregroundStyle(Palette.Text.secondary.color) }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("treemap.loading")
        case let .failed(message):
            EmptyStateView("Treemap Failed", systemImage: "exclamationmark.triangle", message: message)
                .accessibilityIdentifier("treemap.failed")
        case .loaded where session.tree.isEmpty:
            EmptyStateView("No Files at HEAD", systemImage: "square.grid.3x3", message: "The treemap shows the files of the checked-out commit. Commit some files, then open it again.")
                .accessibilityIdentifier("treemap.empty")
        case .loaded:
            TreemapToolbar(session: session)
            TreemapArea(session: session)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Metrics.Radius.card, style: .continuous).strokeBorder(Palette.Surface.border.color, lineWidth: Metrics.Line.hairline))
                .contextMenu { menu }
            TreemapInfoBar(session: session, repository: repository)
        }
    }

    @ViewBuilder
    private var menu: some View {
        let node = session.contextNode
        if let node, case let path = session.tree[node].path, !path.isEmpty {
            Button("Show \(session.tree[node].name) in Changes") { repository.showInChanges(path) }
                .disabled(!session.changedPaths.contains(path))
            Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([repository.fileURL(of: path)]) }
        }
        let target = session.zoomTarget(for: node)
        Button("Zoom In") { target.map(session.zoom(into:)) }
            .disabled(target == nil)
        Button("Zoom Out") { session.zoomOut() }
            .disabled(session.focus == TreemapTree.root)
    }
}

private struct TreemapToolbar: View {
    @Bindable var session: TreemapViewModel

    var body: some View {
        HStack(spacing: Metrics.Spacing.xs) {
            ForEach(Array(session.crumbs.enumerated()), id: \.element.id) { index, crumb in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: Metrics.Icon.disclosure))
                        .foregroundStyle(Palette.Text.secondary.color)
                }
                Button(crumb.title) { session.zoom(into: crumb.node) }
                    .buttonStyle(.morkLink)
                    .disabled(crumb.node == session.focus)
                    .accessibilityIdentifier("treemap.crumb.\(index)")
            }
            Text(LFSPointerChange.size(session.focusNode.size))
                .font(Metrics.Font.caption.monospacedDigit())
                .foregroundStyle(Palette.Text.secondary.color)
                .accessibilityIdentifier("treemap.total")
            Spacer()
            Picker("Color", selection: $session.colorMode) {
                ForEach(TreemapColorMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .accessibilityIdentifier("treemap.colorMode")
        }
        .frame(height: Metrics.Control.regular)
    }
}

private struct TreemapArea: View {
    let session: TreemapViewModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            TreemapCanvas(layout: session.layout, tree: session.tree, mode: session.colorMode)
            TreemapHighlight(session: session)
        }
        .contentShape(Rectangle())
        .onGeometryChange(for: CGSize.self, of: { $0.size }) { session.resize(width: $0.width, height: $0.height) }
        .onContinuousHover { phase in
            switch phase {
            case let .active(point): session.hover(x: point.x, y: point.y)
            case .ended: session.endHover()
            }
        }
        .gesture(SpatialTapGesture(count: 2).onEnded { session.zoom(x: $0.location.x, y: $0.location.y) })
        .simultaneousGesture(SpatialTapGesture().onEnded { session.select(x: $0.location.x, y: $0.location.y) })
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Treemap of \(session.focusNode.fileCount) files")
        .accessibilityIdentifier("treemap.canvas")
    }
}

private struct TreemapCanvas: View {
    let layout: TreemapLayout
    let tree: TreemapTree
    let mode: TreemapColorMode

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, _ in
            var labels = 0
            for tile in layout.tiles {
                let rect = CGRect(x: tile.rect.x, y: tile.rect.y, width: tile.rect.width, height: tile.rect.height)
                let color = TreemapPalette.color(tile.colorKey)
                if tile.isFolder {
                    context.fill(Path(rect), with: .color(color.opacity(Metrics.Treemap.folderFillOpacity)))
                    context.stroke(Path(rect), with: .color(Palette.Text.primary.color.opacity(Metrics.Treemap.folderStrokeOpacity)), lineWidth: Metrics.Line.hairline)
                } else {
                    context.fill(Path(rect.insetBy(dx: Metrics.Treemap.fileInset, dy: Metrics.Treemap.fileInset)), with: .color(color.opacity(Metrics.Treemap.fileFillOpacity + Metrics.Treemap.depthOpacityStep * Double(min(tile.depth, Metrics.Treemap.maximumShadedDepth)))))
                }
                guard labels < Metrics.Treemap.labelLimit, rect.width >= Metrics.Treemap.labelMinimumWidth, rect.height >= Metrics.Treemap.labelMinimumHeight, tile.depth <= 1 || !tile.isFolder else { continue }
                labels += 1
                let label = context.resolve(Text(tree[tile.node].name).font(.system(size: Metrics.Treemap.labelFontSize)).foregroundStyle(Palette.Text.primary.color))
                let inset = rect.insetBy(dx: Metrics.Spacing.xs, dy: Metrics.Spacing.xxs)
                context.draw(label, in: CGRect(x: inset.minX, y: inset.minY, width: inset.width, height: Metrics.Treemap.labelMinimumHeight - Metrics.Spacing.xxs))
            }
        }
    }
}

private struct TreemapHighlight: View {
    let session: TreemapViewModel

    var body: some View {
        let tiles = session.layout.tiles
        let hovered = session.hoveredTile.flatMap { $0 < tiles.count ? tiles[$0].rect : nil }
        let selected = session.selectedTile.flatMap { $0 < tiles.count ? tiles[$0].rect : nil }
        Canvas { context, _ in
            if let hovered {
                context.stroke(path(hovered), with: .color(Palette.Text.primary.color.opacity(Metrics.Treemap.hoverOpacity)), lineWidth: Metrics.Treemap.highlightWidth)
            }
            if let selected {
                context.stroke(path(selected), with: .color(Palette.Accent.fill.color), lineWidth: Metrics.Treemap.highlightWidth)
            }
        }
        .allowsHitTesting(false)
    }

    private func path(_ rect: TreemapRect) -> Path {
        Path(CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height).insetBy(dx: Metrics.Treemap.highlightWidth / 2, dy: Metrics.Treemap.highlightWidth / 2))
    }
}

private struct TreemapInfoBar: View {
    let session: TreemapViewModel
    let repository: RepositoryViewModel

    var body: some View {
        HStack(spacing: Metrics.Spacing.s) {
            Text(info)
                .font(Metrics.Font.monoBody)
                .foregroundStyle(Palette.Text.primary.color)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .accessibilityIdentifier("treemap.info")
            Spacer()
            if let path = session.selectedPath {
                Button("Show in Changes") { repository.showInChanges(path) }
                    .buttonStyle(.morkSecondary)
                    .disabled(!session.canShowSelectionInChanges)
                    .help(session.canShowSelectionInChanges ? "Select this file in Changes" : "This file has no uncommitted changes")
                    .accessibilityIdentifier("treemap.showInChanges")
                Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([repository.fileURL(of: path)]) }
                    .buttonStyle(.morkSecondary)
                    .accessibilityIdentifier("treemap.reveal")
            }
            Button("Zoom In") { session.zoomIn() }
                .buttonStyle(.morkSecondary)
                .disabled(session.zoomTarget == nil)
                .accessibilityIdentifier("treemap.zoomIn")
        }
        .frame(height: Metrics.Control.regular)
    }

    private var info: String {
        if let hovered = session.hoveredTile, hovered < session.layout.tiles.count {
            return session.description(of: session.layout.tiles[hovered].node)
        }
        if let selected = session.selectedNode {
            return session.description(of: selected)
        }
        return "Hover a rectangle to see its path and size. Click to select, double-click to zoom into a folder."
    }
}

enum TreemapPalette {
    static func color(_ key: Int) -> Color {
        key < 0 ? Palette.Status.untracked.ink.color : CommitGraphPalette.color(key)
    }
}
