import Foundation

public struct TreemapFile: Equatable, Sendable {
    public let path: String
    public let size: Int64

    public init(path: String, size: Int64) {
        self.path = path
        self.size = size
    }
}

public struct TreemapRect: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var area: Double { width * height }
    public var shortSide: Double { min(width, height) }

    public func contains(x px: Double, y py: Double) -> Bool {
        px >= x && px < x + width && py >= y && py < y + height
    }

    public func insetBy(_ amount: Double) -> TreemapRect {
        TreemapRect(x: x + amount, y: y + amount, width: max(0, width - amount * 2), height: max(0, height - amount * 2))
    }
}

public enum TreemapColorMode: String, CaseIterable, Identifiable, Sendable {
    case folder
    case fileType

    public var id: String { rawValue }
    public var title: String { self == .folder ? "Top-Level Folder" : "File Type" }
}

public struct TreemapTile: Equatable, Sendable {
    public let node: Int32
    public let rect: TreemapRect
    public let depth: Int
    public let isFolder: Bool
    public let colorKey: Int

    public init(node: Int32, rect: TreemapRect, depth: Int, isFolder: Bool, colorKey: Int) {
        self.node = node
        self.rect = rect
        self.depth = depth
        self.isFolder = isFolder
        self.colorKey = colorKey
    }
}

public struct TreemapLayout: Equatable, Sendable {
    public static let empty = TreemapLayout(tiles: [], width: 0, height: 0)

    public let tiles: [TreemapTile]
    public let width: Double
    public let height: Double

    public init(tiles: [TreemapTile], width: Double, height: Double) {
        self.tiles = tiles
        self.width = width
        self.height = height
    }

    public func tileIndex(atX x: Double, y: Double) -> Int? {
        tiles.indices.reversed().first { tiles[$0].rect.contains(x: x, y: y) }
    }
}
