import Foundation

public enum ConflictSide: String, CaseIterable, Sendable {
    case ours
    case theirs

    public var checkoutFlag: String { "--\(rawValue)" }
}

public enum ConflictStage: Int, CaseIterable, Sendable {
    case base = 1
    case ours = 2
    case theirs = 3

    public func revision(of path: String) -> String { ":\(rawValue):\(path)" }
}

public struct ConflictStages: Equatable, Sendable {
    public let base: Data?
    public let ours: Data?
    public let theirs: Data?

    public init(base: Data? = nil, ours: Data? = nil, theirs: Data? = nil) {
        self.base = base
        self.ours = ours
        self.theirs = theirs
    }
}

public enum ConflictMarkerStyle: Hashable, Sendable {
    case merge
    case zdiff3
}

public struct ConflictMergeInput: Hashable, Sendable {
    public let name: String
    public let ours: Data
    public let base: Data
    public let theirs: Data
    public let oursLabel: String
    public let baseLabel: String
    public let theirsLabel: String

    public init(name: String, ours: Data, base: Data, theirs: Data, oursLabel: String, baseLabel: String, theirsLabel: String) {
        self.name = name
        self.ours = ours
        self.base = base
        self.theirs = theirs
        self.oursLabel = oursLabel
        self.baseLabel = baseLabel
        self.theirsLabel = theirsLabel
    }
}

public enum ConflictChoice: String, CaseIterable, Sendable {
    case ours
    case theirs
    case oursThenTheirs
    case theirsThenOurs
}

public enum ConflictFileResolution: String, CaseIterable, Sendable {
    case ours
    case theirs
    case keep
    case delete

    public var title: String {
        switch self {
        case .ours: "Resolve Using Ours"
        case .theirs: "Resolve Using Theirs"
        case .keep: "Keep File"
        case .delete: "Delete File"
        }
    }
}

public enum ConflictKind: CaseIterable, Sendable {
    case bothModified
    case bothAdded
    case deletedByUs
    case deletedByThem
    case addedByUs
    case addedByThem
    case bothDeleted

    public init?(_ change: FileChange) {
        switch (change.index, change.worktree) {
        case ("U", "U"): self = .bothModified
        case ("A", "A"): self = .bothAdded
        case ("D", "U"): self = .deletedByUs
        case ("U", "D"): self = .deletedByThem
        case ("A", "U"): self = .addedByUs
        case ("U", "A"): self = .addedByThem
        case ("D", "D"): self = .bothDeleted
        default: return nil
        }
    }

    public var statusCode: String {
        switch self {
        case .bothModified: "UU"
        case .bothAdded: "AA"
        case .deletedByUs: "DU"
        case .deletedByThem: "UD"
        case .addedByUs: "AU"
        case .addedByThem: "UA"
        case .bothDeleted: "DD"
        }
    }

    public var hasContentConflict: Bool { self == .bothModified || self == .bothAdded }

    public var stages: [ConflictStage] {
        switch self {
        case .bothModified: [.base, .ours, .theirs]
        case .bothAdded: [.ours, .theirs]
        case .deletedByUs, .deletedByThem, .addedByUs, .addedByThem, .bothDeleted: []
        }
    }

    public var resolutions: [ConflictFileResolution] {
        switch self {
        case .bothModified: [.ours, .theirs]
        case .bothAdded: [.ours, .theirs, .delete]
        case .deletedByUs, .deletedByThem, .addedByUs, .addedByThem: [.keep, .delete]
        case .bothDeleted: [.delete]
        }
    }

    public var deletedBy: [ConflictSide] {
        switch self {
        case .deletedByUs: [.ours]
        case .deletedByThem: [.theirs]
        case .bothDeleted: [.ours, .theirs]
        case .bothModified, .bothAdded, .addedByUs, .addedByThem: []
        }
    }

    public var title: String {
        switch self {
        case .bothModified: "Both modified"
        case .bothAdded: "Both added"
        case .deletedByUs: "Deleted by us"
        case .deletedByThem: "Deleted by them"
        case .addedByUs: "Added by us"
        case .addedByThem: "Added by them"
        case .bothDeleted: "Deleted by both"
        }
    }

    public var explanation: String {
        switch self {
        case .bothModified:
            "Both sides changed the same lines. Pick a side for each conflict block, or for the whole file."
        case .bothAdded:
            "Both sides added a file at this path with different content. Pick a side per block or for the whole file, or delete it."
        case .deletedByUs:
            "Our side (HEAD) deleted this file and the incoming side changed it. The file on disk is the incoming version. Keep it (git add) or delete it (git rm)."
        case .deletedByThem:
            "The incoming side deleted this file and our side (HEAD) changed it. The file on disk is our version. Keep it (git add) or delete it (git rm)."
        case .addedByUs:
            "Only our side (HEAD) has a file at this path, usually after both sides renamed the same file differently. Keep it (git add) or delete it (git rm)."
        case .addedByThem:
            "Only the incoming side has a file at this path, usually after both sides renamed the same file differently. Keep it (git add) or delete it (git rm)."
        case .bothDeleted:
            "Both sides deleted or renamed away this file. Delete it (git rm) to resolve."
        }
    }
}

public struct ConflictBlock: Identifiable, Equatable, Sendable {
    public let index: Int
    public let ours: String
    public let base: String?
    public let theirs: String
    public let oursLabel: String
    public let baseLabel: String?
    public let theirsLabel: String
    public let raw: String

    public init(index: Int, ours: String, base: String?, theirs: String, oursLabel: String, baseLabel: String?, theirsLabel: String, raw: String) {
        self.index = index
        self.ours = ours
        self.base = base
        self.theirs = theirs
        self.oursLabel = oursLabel
        self.baseLabel = baseLabel
        self.theirsLabel = theirsLabel
        self.raw = raw
    }

    public var id: Int { index }

    public func text(for choice: ConflictChoice, lineEnding: String) -> String {
        switch choice {
        case .ours: ours
        case .theirs: theirs
        case .oursThenTheirs: Self.join(ours, theirs, lineEnding: lineEnding)
        case .theirsThenOurs: Self.join(theirs, ours, lineEnding: lineEnding)
        }
    }

    private static func join(_ first: String, _ second: String, lineEnding: String) -> String {
        guard !first.isEmpty, !second.isEmpty, first.utf8.last != UInt8(ascii: "\n") else { return first + second }
        return first + lineEnding + second
    }
}

public enum ConflictSegment: Equatable, Sendable {
    case common(String)
    case conflict(ConflictBlock)
}

public struct ConflictDocument: Equatable, Sendable {
    public let segments: [ConflictSegment]
    public let lineEnding: String
    public let blocks: [ConflictBlock]

    public init(segments: [ConflictSegment], lineEnding: String) {
        self.segments = segments
        self.lineEnding = lineEnding
        blocks = segments.compactMap { segment in
            guard case let .conflict(block) = segment else { return nil }
            return block
        }
    }

    public var text: String {
        segments.map { segment in
            switch segment {
            case let .common(text): text
            case let .conflict(block): block.raw
            }
        }.joined()
    }
}

public enum ConflictContent: Equatable, Sendable {
    case text(ConflictDocument)
    case binary
    case missing
}

public struct ConflictFile: Equatable, Sendable {
    public let path: String
    public let kind: ConflictKind
    public let content: ConflictContent
    public let stages: ConflictStages
    public let documentWithBase: ConflictDocument?

    public init(path: String, kind: ConflictKind, content: ConflictContent, stages: ConflictStages = ConflictStages(), documentWithBase: ConflictDocument? = nil) {
        self.path = path
        self.kind = kind
        self.content = content
        self.stages = stages
        self.documentWithBase = documentWithBase
    }

    public var document: ConflictDocument? {
        guard case let .text(document) = content else { return nil }
        return document
    }
}

public enum ConflictError: LocalizedError, Equatable, Sendable {
    case notConflicted(path: String)
    case unavailable(ConflictFileResolution, ConflictKind)
    case markersRemain(Int)
    case unresolvedFiles(Int)

    public var errorDescription: String? {
        switch self {
        case let .notConflicted(path):
            "\(path) has no conflict."
        case let .unavailable(resolution, kind):
            "\(resolution.title) is not possible for a file that is \(kind.title.lowercased()) (\(kind.statusCode))."
        case let .markersRemain(count):
            "The file still has \(count) conflict block(s) with <<<<<<< markers. Resolve them first, or confirm to stage the file as it is."
        case let .unresolvedFiles(count):
            "\(count) file(s) still have conflicts. Resolve them before you commit the merge."
        }
    }
}

extension FileChange {
    public var conflictKind: ConflictKind? { ConflictKind(self) }
}

extension RepositorySnapshot {
    public var conflictedChanges: [FileChange] { changes.filter(\.isConflicted) }
}
