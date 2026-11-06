import MorkDomain
import Foundation

public struct FetchForm: Equatable, Sendable {
    public let remotes: [String]
    public var remote: String?
    public var prune = true
    public var tags = false
    public var refspec = ""

    public init(remotes: [String]) {
        self.remotes = remotes
        remote = remotes.count == 1 ? remotes.first : nil
    }

    public var acceptsRefspec: Bool { remote != nil }

    public var options: FetchOptions? {
        guard !remotes.isEmpty else { return nil }
        if let remote, !remotes.contains(remote) { return nil }
        return FetchOptions(remote: remote, prune: prune, tags: tags, refspec: refspec)
    }

    public var problem: String? { options?.problem?.errorDescription }

    public var canFetch: Bool { options.map { $0.problem == nil } ?? false }

    public var command: String {
        options.map { (["git"] + $0.arguments).map(ShellWords.quote).joined(separator: " ") } ?? ""
    }
}
