import Foundation

public struct Branch: Identifiable, Hashable, Sendable {
    private static let remotePrefix = "refs/remotes/"

    public let name: String
    public let fullName: String
    public let isCurrent: Bool
    public let upstream: String?
    public let track: String
    public let hash: String

    public init(name: String, fullName: String, isCurrent: Bool, upstream: String?, track: String, hash: String = "") {
        self.name = name
        self.fullName = fullName
        self.isCurrent = isCurrent
        self.upstream = upstream
        self.track = track
        self.hash = hash
    }

    public var id: String { fullName }
    public var isRemote: Bool { fullName.hasPrefix(Self.remotePrefix) }
    public var isUpstreamGone: Bool { track == "[gone]" }
    public var ahead: Int { trackCount("ahead") }
    public var behind: Int { trackCount("behind") }

    public var remoteName: String? {
        guard isRemote else { return nil }
        return fullName.dropFirst(Self.remotePrefix.count).split(separator: "/").first.map(String.init)
    }

    public var localName: String {
        guard let remoteName else { return name }
        return String(fullName.dropFirst(Self.remotePrefix.count + remoteName.count + 1))
    }

    private func trackCount(_ label: String) -> Int {
        guard track.hasPrefix("["), track.hasSuffix("]") else { return 0 }
        let parts = track.dropFirst().dropLast().components(separatedBy: ", ")
        for part in parts {
            let words = part.split(separator: " ")
            if words.count == 2, words[0] == label, let count = Int(words[1]) {
                return count
            }
        }
        return 0
    }
}
