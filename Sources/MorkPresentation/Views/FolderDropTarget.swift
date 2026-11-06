import SwiftUI
import UniformTypeIdentifiers

extension View {
    func folderDropTarget(_ app: AppViewModel) -> some View {
        modifier(FolderDropTarget(app: app))
    }
}

extension EnvironmentValues {
    var forcesFolderDropOverlay: Bool {
        get { self[ForcesFolderDropOverlayKey.self] }
        set { self[ForcesFolderDropOverlayKey.self] = newValue }
    }
}

private struct ForcesFolderDropOverlayKey: EnvironmentKey {
    static let defaultValue = false
}

private struct FolderDropTarget: ViewModifier {
    let app: AppViewModel
    @Environment(\.forcesFolderDropOverlay) private var isForced
    @State private var isTargeted = false
    @State private var holdsFolder = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if isForced || (isTargeted && holdsFolder) {
                    FolderDropOverlay()
                }
            }
            .onDrop(of: [.fileURL], delegate: FolderDropDelegate(app: app, isTargeted: $isTargeted, holdsFolder: $holdsFolder))
    }
}

private struct FolderDropOverlay: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.Radius.card, style: .continuous)
        shape
            .fill(Palette.Accent.tint.color.opacity(Metrics.DropTarget.fillOpacity))
            .overlay {
                shape.strokeBorder(Palette.Accent.text.color, style: StrokeStyle(lineWidth: Metrics.DropTarget.border, dash: Metrics.DropTarget.dash))
            }
            .overlay {
                EmptyStateView("Drop a folder to open it as a repository", systemImage: "folder.badge.plus")
            }
            .padding(Metrics.DropTarget.inset)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("welcome.dropTarget")
    }
}

@MainActor
private struct FolderDropDelegate: DropDelegate {
    let app: AppViewModel
    @Binding var isTargeted: Bool
    @Binding var holdsFolder: Bool

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.fileURL])
    }

    func dropEntered(info: DropInfo) {
        isTargeted = true
        holdsFolder = false
        let providers = info.itemProviders(for: [.fileURL])
        Task {
            let folders = await app.droppableFolders(await Self.fileURLs(from: providers))
            if isTargeted { holdsFolder = !folders.isEmpty }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .copy)
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
        holdsFolder = false
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        holdsFolder = false
        let providers = info.itemProviders(for: [.fileURL])
        guard !providers.isEmpty else { return false }
        Task { await app.openDropped(await Self.fileURLs(from: providers)) }
        return true
    }

    private static func fileURLs(from providers: [NSItemProvider]) async -> [URL] {
        var urls: [URL] = []
        for provider in providers {
            if let url = await fileURL(from: provider) { urls.append(url) }
        }
        return urls
    }

    private static func fileURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url)
            }
        }
    }
}
