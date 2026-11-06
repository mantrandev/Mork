import Foundation

public enum TreemapLayoutEngine {
    public static let folderPadding = 2.0
    public static let minimumSide = 3.0
    public static let tileLimit = 40_000

    public static func squarify(_ sizes: [Double], in bounds: TreemapRect) -> [TreemapRect] {
        let total = sizes.reduce(0, +)
        guard total > 0, bounds.width > 0, bounds.height > 0 else {
            return sizes.map { _ in TreemapRect(x: bounds.x, y: bounds.y, width: 0, height: 0) }
        }
        let scale = bounds.area / total
        let areas = sizes.map { $0 * scale }
        var rects = [TreemapRect](repeating: TreemapRect(x: bounds.x, y: bounds.y, width: 0, height: 0), count: sizes.count)
        var free = bounds
        var start = 0
        while start < areas.count {
            let side = free.shortSide
            guard side > 0 else { break }
            var end = start + 1
            var rowArea = areas[start]
            var worst = worstRatio(areas[start..<end], sum: rowArea, side: side)
            while end < areas.count {
                let candidateArea = rowArea + areas[end]
                let candidate = worstRatio(areas[start...end], sum: candidateArea, side: side)
                guard candidate <= worst else { break }
                worst = candidate
                rowArea = candidateArea
                end += 1
            }
            free = place(areas, start..<end, rowArea: rowArea, in: free, into: &rects)
            start = end
        }
        return rects
    }

    public static func layout(_ tree: TreemapTree, focus: Int32, width: Double, height: Double, colorMode: TreemapColorMode) -> TreemapLayout {
        guard width > 0, height > 0, Int(focus) < tree.nodes.count else { return .empty }
        var tiles: [TreemapTile] = []
        tiles.reserveCapacity(min(tree.nodes.count, tileLimit))
        var extensionKeys: [String: Int] = [:]
        let focusNode = tree[focus]
        let bounds = TreemapRect(x: 0, y: 0, width: width, height: height)
        if !focusNode.isFolder {
            tiles.append(TreemapTile(node: focus, rect: bounds, depth: 0, isFolder: false, colorKey: colorKey(for: focusNode, group: 0, mode: colorMode, extensions: &extensionKeys)))
            return TreemapLayout(tiles: tiles, width: width, height: height)
        }
        var queue: [(node: Int32, rect: TreemapRect, depth: Int, group: Int)] = []
        let children = focusNode.children.filter { tree[$0].size > 0 }
        let rects = squarify(children.map { Double(tree[$0].size) }, in: bounds)
        for (offset, child) in children.enumerated() {
            queue.append((child, rects[offset], 0, offset))
        }
        var head = 0
        while head < queue.count, tiles.count < tileLimit {
            let item = queue[head]
            head += 1
            guard item.rect.width >= 1, item.rect.height >= 1 else { continue }
            let node = tree[item.node]
            tiles.append(TreemapTile(node: item.node, rect: item.rect, depth: item.depth, isFolder: node.isFolder, colorKey: colorKey(for: node, group: item.group, mode: colorMode, extensions: &extensionKeys)))
            guard node.isFolder else { continue }
            let inner = item.rect.insetBy(folderPadding)
            guard inner.shortSide >= minimumSide else { continue }
            let nested = node.children.filter { tree[$0].size > 0 }
            let nestedRects = squarify(nested.map { Double(tree[$0].size) }, in: inner)
            for (offset, child) in nested.enumerated() where nestedRects[offset].shortSide >= 1 {
                queue.append((child, nestedRects[offset], item.depth + 1, item.group))
            }
        }
        return TreemapLayout(tiles: tiles, width: width, height: height)
    }

    private static func colorKey(for node: TreemapTree.Node, group: Int, mode: TreemapColorMode, extensions: inout [String: Int]) -> Int {
        switch mode {
        case .folder:
            return group
        case .fileType:
            guard !node.isFolder else { return -1 }
            if let key = extensions[node.fileExtension] { return key }
            let key = extensions.count
            extensions[node.fileExtension] = key
            return key
        }
    }

    private static func worstRatio(_ row: ArraySlice<Double>, sum: Double, side: Double) -> Double {
        guard sum > 0, let largest = row.max(), let smallest = row.min(), smallest > 0 else { return .infinity }
        let sideSquared = side * side
        let sumSquared = sum * sum
        return max(sideSquared * largest / sumSquared, sumSquared / (sideSquared * smallest))
    }

    private static func place(_ areas: [Double], _ range: Range<Int>, rowArea: Double, in free: TreemapRect, into rects: inout [TreemapRect]) -> TreemapRect {
        if free.width >= free.height {
            let columnWidth = min(free.width, rowArea / free.height)
            var y = free.y
            for index in range {
                let height = columnWidth > 0 ? areas[index] / columnWidth : 0
                rects[index] = TreemapRect(x: free.x, y: y, width: columnWidth, height: height)
                y += height
            }
            return TreemapRect(x: free.x + columnWidth, y: free.y, width: free.width - columnWidth, height: free.height)
        }
        let rowHeight = min(free.height, rowArea / free.width)
        var x = free.x
        for index in range {
            let width = rowHeight > 0 ? areas[index] / rowHeight : 0
            rects[index] = TreemapRect(x: x, y: free.y, width: width, height: rowHeight)
            x += width
        }
        return TreemapRect(x: free.x, y: free.y + rowHeight, width: free.width, height: free.height - rowHeight)
    }
}
