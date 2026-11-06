import Foundation

public enum FetchOptionsError: LocalizedError, Equatable, Sendable {
    case invalidRefspec(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidRefspec(refspec):
            "“\(refspec)” is not a refspec. A refspec names what to fetch, like main or +refs/heads/*:refs/remotes/origin/*, and never starts with -."
        }
    }
}

public struct FetchOptions: Equatable, Sendable {
    public let remote: String?
    public let prune: Bool
    public let tags: Bool
    public let refspecs: [String]

    public init(remote: String?, prune: Bool, tags: Bool, refspec: String = "") {
        self.remote = remote
        self.prune = prune
        self.tags = tags
        refspecs = remote == nil ? [] : refspec.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    public var arguments: [String] {
        ["fetch"]
            + (remote == nil ? ["--all"] : [])
            + (prune ? ["--prune"] : [])
            + (tags ? ["--tags"] : [])
            + (remote.map { [$0] } ?? [])
            + refspecs
    }

    public var problem: FetchOptionsError? {
        refspecs.first { $0.hasPrefix("-") }.map(FetchOptionsError.invalidRefspec)
    }
}
