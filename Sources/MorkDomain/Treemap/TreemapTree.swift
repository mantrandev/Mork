import Foundation

public struct TreemapTree: Equatable, Sendable {
    public struct Node: Equatable, Sendable {
        public let name: String
        public let path: String
        public let size: Int64
        public let parent: Int32
        public let children: [Int32]
        public let isFolder: Bool
        public let fileCount: Int

        public var fileExtension: String {
            guard !isFolder, let dot = name.lastIndex(of: "."), dot != name.startIndex else { return "" }
            return name[name.index(after: dot)...].lowercased()
        }
    }

    public static let root: Int32 = 0

    public let nodes: [Node]

    public init(nodes: [Node]) {
        self.nodes = nodes
    }

    public var isEmpty: Bool { nodes.count <= 1 }
    public var totalSize: Int64 { nodes.first?.size ?? 0 }

    public subscript(index: Int32) -> Node { nodes[Int(index)] }

    public func ancestors(of index: Int32) -> [Int32] {
        var chain: [Int32] = []
        var current = index
        while current >= 0 {
            chain.append(current)
            current = nodes[Int(current)].parent
        }
        return chain.reversed()
    }

    public func node(atPath path: String) -> Int32? {
        guard !path.isEmpty else { return Self.root }
        var current = Self.root
        for component in path.split(separator: "/") {
            guard let next = nodes[Int(current)].children.first(where: { nodes[Int($0)].name == component }) else { return nil }
            current = next
        }
        return current
    }

    public static func build(_ files: [TreemapFile]) -> TreemapTree {
        final class Draft {
            let name: String
            let path: String
            var size: Int64 = 0
            var fileCount = 0
            var folders: [Substring: Draft] = [:]
            var files: [(name: String, path: String, size: Int64)] = []

            init(name: String, path: String) {
                self.name = name
                self.path = path
            }
        }

        let root = Draft(name: "", path: "")
        for file in files {
            var folder = root
            var components = file.path.split(separator: "/")
            guard let name = components.popLast() else { continue }
            folder.size += file.size
            folder.fileCount += 1
            for component in components {
                if let existing = folder.folders[component] {
                    folder = existing
                } else {
                    let path = folder.path.isEmpty ? String(component) : folder.path + "/" + component
                    let created = Draft(name: String(component), path: path)
                    folder.folders[component] = created
                    folder = created
                }
                folder.size += file.size
                folder.fileCount += 1
            }
            folder.files.append((String(name), file.path, file.size))
        }

        var nodes: [Node] = []
        nodes.reserveCapacity(files.count * 2)
        func emit(_ draft: Draft, parent: Int32) -> Int32 {
            let index = Int32(nodes.count)
            nodes.append(Node(name: draft.name, path: draft.path, size: draft.size, parent: parent, children: [], isFolder: true, fileCount: draft.fileCount))
            var children: [(index: Int32, size: Int64, name: String)] = []
            for folder in draft.folders.values {
                children.append((emit(folder, parent: index), folder.size, folder.name))
            }
            for file in draft.files {
                let fileIndex = Int32(nodes.count)
                nodes.append(Node(name: file.name, path: file.path, size: file.size, parent: index, children: [], isFolder: false, fileCount: 1))
                children.append((fileIndex, file.size, file.name))
            }
            children.sort { $0.size != $1.size ? $0.size > $1.size : $0.name < $1.name }
            let node = nodes[Int(index)]
            nodes[Int(index)] = Node(name: node.name, path: node.path, size: node.size, parent: node.parent, children: children.map(\.index), isFolder: true, fileCount: node.fileCount)
            return index
        }
        _ = emit(root, parent: -1)
        return TreemapTree(nodes: nodes)
    }
}
