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
        case more
    }

    private static let headPrefix = "HEAD -> "
    private static let tagPrefix = "tag: "

    let kind: Kind
    let name: String
    var others: [String] = []

    static func labels(for refNames: [String], remotes: Set<String>) -> [RefLabel] {
        refNames.map { label(for: $0, remotes: remotes) }
    }

    static func historyBadges(_ labels: [RefLabel]) -> [RefLabel] {
        let tags = labels.filter { $0.kind == .tag }.map(\.name).sorted { $0.localizedStandardCompare($1) == .orderedDescending }
        let branches = mergingRemotes(labels.filter { $0.kind != .tag })
        guard let newest = tags.first else { return branches }
        return branches + [RefLabel(kind: .tag, name: newest, others: Array(tags.dropFirst()))]
    }

    private static func mergingRemotes(_ labels: [RefLabel]) -> [RefLabel] {
        let locals = Set(labels.filter { $0.kind == .localBranch || $0.kind == .currentBranch }.map(\.name))
        let merged = labels.filter { $0.kind == .remoteBranch && trackedName(of: $0.name).map(locals.contains) == true }
        let byLocal = Dictionary(grouping: merged.map(\.name)) { trackedName(of: $0) ?? "" }
        return labels.compactMap { label in
            if label.kind == .remoteBranch, merged.contains(label) { return nil }
            guard label.kind == .localBranch || label.kind == .currentBranch, let remotes = byLocal[label.name] else { return label }
            return RefLabel(kind: label.kind, name: label.name, others: remotes)
        }
    }

    private static func trackedName(of remote: String) -> String? {
        guard let slash = remote.firstIndex(of: "/") else { return nil }
        let name = String(remote[remote.index(after: slash)...])
        return name.isEmpty ? nil : name
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
