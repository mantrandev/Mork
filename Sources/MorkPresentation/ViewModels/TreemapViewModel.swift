import MorkDomain
import Foundation
import Observation

@MainActor
@Observable
public final class TreemapViewModel: Identifiable {
    public enum Status: Equatable, Sendable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    public struct Crumb: Identifiable, Equatable, Sendable {
        public let node: Int32
        public let title: String

        public var id: Int32 { node }
    }

    public let id = UUID()
    public let repositoryName: String
    public let changedPaths: Set<String>
    public private(set) var status: Status = .idle
    public private(set) var tree = TreemapTree.build([])
    public private(set) var focus = TreemapTree.root
    public private(set) var layout = TreemapLayout.empty
    public private(set) var hoveredTile: Int?
    public private(set) var selectedNode: Int32?
    public private(set) var selectedTile: Int?
    public var colorMode = TreemapColorMode.folder {
        didSet { if colorMode != oldValue { relayout() } }
    }

    @ObservationIgnored private var size: (width: Double, height: Double) = (0, 0)
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var layoutTask: Task<Void, Never>?
    private let loadTreemap: LoadTreemapUseCaseProtocol

    public init(repositoryName: String, changedPaths: Set<String>, loadTreemap: LoadTreemapUseCaseProtocol) {
        self.repositoryName = repositoryName
        self.changedPaths = changedPaths
        self.loadTreemap = loadTreemap
    }

    public var crumbs: [Crumb] {
        tree.ancestors(of: focus).map { Crumb(node: $0, title: $0 == TreemapTree.root ? repositoryName : tree[$0].name) }
    }

    public var focusNode: TreemapTree.Node { tree[focus] }

    public var selectedPath: String? { selectedNode.map { tree[$0].path } }

    public var canShowSelectionInChanges: Bool {
        selectedPath.map(changedPaths.contains) ?? false
    }

    public var zoomTarget: Int32? { zoomTarget(for: selectedNode) }

    public var contextNode: Int32? {
        hoveredTile.flatMap { $0 < layout.tiles.count ? layout.tiles[$0].node : nil } ?? selectedNode
    }

    public func zoomTarget(for node: Int32?) -> Int32? {
        guard let node else { return nil }
        let chain = tree.ancestors(of: node)
        guard let index = chain.firstIndex(of: focus), index + 1 < chain.count else { return nil }
        let target = chain[index + 1]
        return tree[target].isFolder ? target : nil
    }

    public func description(of node: Int32) -> String {
        let entry = tree[node]
        let size = LFSPointerChange.size(entry.size)
        let path = entry.path.isEmpty ? repositoryName : entry.path
        return entry.isFolder ? "\(path)/ · \(size) · \(entry.fileCount) file\(entry.fileCount == 1 ? "" : "s")" : "\(path) · \(size)"
    }

    public func load() async {
        status = .loading
        do {
            let loaded = try await loadTreemap.execute()
            tree = loaded
            focus = TreemapTree.root
            status = .loaded
            relayout()
            await waitForLayout()
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    public func resize(width: Double, height: Double) {
        guard abs(width - size.width) >= 1 || abs(height - size.height) >= 1 else { return }
        size = (width, height)
        relayout()
    }

    public func hover(x: Double, y: Double) {
        let index = layout.tileIndex(atX: x, y: y)
        if hoveredTile != index { hoveredTile = index }
    }

    public func endHover() {
        if hoveredTile != nil { hoveredTile = nil }
    }

    public func select(x: Double, y: Double) {
        selectedTile = layout.tileIndex(atX: x, y: y)
        selectedNode = selectedTile.map { layout.tiles[$0].node }
    }

    public func zoom(x: Double, y: Double) {
        select(x: x, y: y)
        if let target = zoomTarget { zoom(into: target) }
    }

    public func zoom(into node: Int32) {
        guard Int(node) < tree.nodes.count, tree[node].isFolder, node != focus else { return }
        focus = node
        hoveredTile = nil
        relayout()
    }

    public func zoomIn() {
        if let target = zoomTarget { zoom(into: target) }
    }

    public func zoomOut() {
        let parent = tree[focus].parent
        guard parent >= 0 else { return }
        focus = parent
        hoveredTile = nil
        relayout()
    }

    public func waitForLayout() async {
        await layoutTask?.value
    }

    private func relayout() {
        generation += 1
        let current = generation
        let tree = tree
        let focus = focus
        let size = size
        let mode = colorMode
        layoutTask = Task { [weak self] in
            let next = await Task.detached(priority: .userInitiated) {
                TreemapLayoutEngine.layout(tree, focus: focus, width: size.width, height: size.height, colorMode: mode)
            }.value
            guard let self, current == self.generation else { return }
            self.hoveredTile = nil
            self.layout = next
            self.selectedTile = self.selectedNode.flatMap { node in next.tiles.firstIndex { $0.node == node } }
        }
    }
}
