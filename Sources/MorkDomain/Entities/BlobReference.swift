import Foundation

public struct BlobReference: Hashable, Sendable {
    public enum Revision: Hashable, Sendable {
        case commit(String)
        case object(String)
        case index
        case workingTree
    }

    public let revision: Revision
    public let path: String

    public init(revision: Revision, path: String) {
        self.revision = revision
        self.path = path
    }

    public static func commit(_ hash: String, _ path: String) -> BlobReference {
        BlobReference(revision: .commit(hash), path: path)
    }

    public static func object(_ id: String, path: String) -> BlobReference {
        BlobReference(revision: .object(id), path: path)
    }

    public var objectName: String? {
        switch revision {
        case let .commit(hash): "\(hash):\(path)"
        case let .object(id): id
        case .index: ":0:\(path)"
        case .workingTree: nil
        }
    }
}
