import MorkDomain
import Foundation

struct RefLabel: Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case currentBranch
        case localBranch
        case remoteBranch
        case tag
        case detachedHead
        case stash
    }

    private static let headPrefix = "HEAD -> "
    private static let tagPrefix = "tag: "

    let kind: Kind
    let name: String

    static func labels(for refNames: [String], remotes: Set<String>) -> [RefLabel] {
        refNames.map { label(for: $0, remotes: remotes) }
    }

    private static func label(for ref: String, remotes: Set<String>) -> RefLabel {
        if ref.hasPrefix(headPrefix) { return RefLabel(kind: .currentBranch, name: String(ref.dropFirst(headPrefix.count))) }
        if ref == "HEAD" { return RefLabel(kind: .detachedHead, name: ref) }
        if ref.hasPrefix(tagPrefix) { return RefLabel(kind: .tag, name: String(ref.dropFirst(tagPrefix.count))) }
        if StashHistory.isStashRef(ref) { return RefLabel(kind: .stash, name: ref) }
        if let remote = ref.split(separator: "/", maxSplits: 1).first, ref.contains("/"), remotes.contains(String(remote)) {
            return RefLabel(kind: .remoteBranch, name: ref)
        }
        return RefLabel(kind: .localBranch, name: ref)
    }
}
