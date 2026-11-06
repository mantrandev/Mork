import MorkDomain
import Foundation
import Observation

public enum LFSSheet: Identifiable, Hashable, Sendable {
    case track
    case untrack
    case transfer(LFSTransfer)

    public var id: String {
        switch self {
        case .track: "track"
        case .untrack: "untrack"
        case let .transfer(transfer): "transfer.\(transfer.rawValue)"
        }
    }
}

public struct LFSTransferState: Equatable, Sendable {
    public internal(set) var isRunning = false
    public internal(set) var progress = GitProgressLog()
    public internal(set) var failure: String?

    public init() {}
}

public struct CommitLFSFiles: Equatable, Sendable {
    public let commit: String
    public let paths: Set<String>
}

@MainActor
@Observable
public final class AdvancedTools {
    public internal(set) var lfsInstallation: LFSInstallation?
    public internal(set) var lfsPaths: Set<String> = []
    public internal(set) var commitLFSFiles: CommitLFSFiles?
    public internal(set) var lfsPointer: LFSPointerChange?
    public internal(set) var lfsPatterns: Loadable<[String]> = .idle
    public internal(set) var lfsTransfer = LFSTransferState()
    public var lfsSheet: LFSSheet?
    public var gitFlow: GitFlowViewModel?
    public var treemap: TreemapViewModel?
    public var benchmark: BenchmarkViewModel?

    @ObservationIgnored var lfsDetection: Task<Void, Never>?
    @ObservationIgnored var lfsMarkers: Task<Void, Never>?

    public init() {}
}
