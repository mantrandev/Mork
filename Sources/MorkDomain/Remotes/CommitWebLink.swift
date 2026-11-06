import Foundation

public struct CommitWebLink: Equatable, Sendable {
    public enum Host: String, Sendable {
        case github
        case gitlab
        case bitbucket
        case gitea

        public var title: String {
            switch self {
            case .github: "GitHub"
            case .gitlab: "GitLab"
            case .bitbucket: "Bitbucket"
            case .gitea: "Gitea"
            }
        }
    }

    private enum Style: Equatable, Sendable {
        case commit
        case gitlab
        case bitbucketCloud
        case bitbucketServer(project: String, repository: String)
    }

    public let host: Host
    private let base: URL
    private let style: Style

    public init?(remoteURL: String) {
        guard let location = Self.location(of: remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = Self.host(named: location.host) else { return nil }
        var components = location.path.split(separator: "/").map(String.init)
        if let last = components.last, last.hasSuffix(".git") { components[components.count - 1] = String(last.dropLast(4)) }
        components.removeAll(where: \.isEmpty)
        let style: Style
        switch host {
        case .bitbucket where location.host != "bitbucket.org":
            if components.first == "scm" { components.removeFirst() }
            guard components.count == 2 else { return nil }
            style = .bitbucketServer(project: components[0], repository: components[1])
        case .bitbucket:
            style = .bitbucketCloud
        case .gitlab:
            style = .gitlab
        case .github, .gitea:
            style = .commit
        }
        guard components.count >= 2 else { return nil }
        var url = URLComponents()
        url.scheme = location.scheme
        url.host = location.host
        url.port = location.port
        if case .bitbucketServer = style {
            url.path = ""
        } else {
            url.path = "/" + components.joined(separator: "/")
        }
        guard let base = url.url else { return nil }
        self.host = host
        self.base = base
        self.style = style
    }

    public func commitURL(_ hash: String) -> URL {
        switch style {
        case .commit: base.appendingPathComponent("commit").appendingPathComponent(hash)
        case .gitlab: base.appendingPathComponent("-").appendingPathComponent("commit").appendingPathComponent(hash)
        case .bitbucketCloud: base.appendingPathComponent("commits").appendingPathComponent(hash)
        case let .bitbucketServer(project, repository):
            base.appendingPathComponent("projects").appendingPathComponent(project).appendingPathComponent("repos")
                .appendingPathComponent(repository).appendingPathComponent("commits").appendingPathComponent(hash)
        }
    }

    public var repositoryURL: URL {
        switch style {
        case .commit, .gitlab, .bitbucketCloud: base
        case .bitbucketServer: serverRepository.appendingPathComponent("browse")
        }
    }

    public var issuesURL: URL? {
        switch style {
        case .commit, .bitbucketCloud: base.appendingPathComponent("issues")
        case .gitlab: base.appendingPathComponent("-").appendingPathComponent("issues")
        case .bitbucketServer: nil
        }
    }

    public var pullRequestsURL: URL {
        switch style {
        case .commit: base.appendingPathComponent("pulls")
        case .gitlab: base.appendingPathComponent("-").appendingPathComponent("merge_requests")
        case .bitbucketCloud: base.appendingPathComponent("pull-requests")
        case .bitbucketServer: serverRepository.appendingPathComponent("pull-requests")
        }
    }

    private var serverRepository: URL {
        guard case let .bitbucketServer(project, repository) = style else { return base }
        return base.appendingPathComponent("projects").appendingPathComponent(project).appendingPathComponent("repos").appendingPathComponent(repository)
    }

    public func pullRequestURL(branch: String, base: String?) -> URL? {
        switch style {
        case .commit:
            let range = (base.map { Self.path($0) + "..." } ?? "") + Self.path(branch)
            return URL(string: root + "/compare/" + range + (host == .github ? "?expand=1" : ""))
        case .gitlab:
            let target = base.map { "&merge_request%5Btarget_branch%5D=" + Self.query($0) } ?? ""
            return URL(string: root + "/-/merge_requests/new?merge_request%5Bsource_branch%5D=" + Self.query(branch) + target)
        case .bitbucketCloud:
            let target = base.map { "&dest=" + Self.query($0) } ?? ""
            return URL(string: root + "/pull-requests/new?source=" + Self.query(branch) + target)
        case let .bitbucketServer(project, repository):
            let target = base.map { "&targetBranch=" + Self.query("refs/heads/" + $0) } ?? ""
            return URL(string: root + "/projects/\(Self.path(project))/repos/\(Self.path(repository))/pull-requests?create&sourceBranch="
                + Self.query("refs/heads/" + branch) + target)
        }
    }

    private var root: String {
        var text = base.absoluteString
        while text.hasSuffix("/") { text.removeLast() }
        return text
    }

    private static let queryCharacters = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&+=#"))

    private static func path(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? text
    }

    private static func query(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: queryCharacters) ?? text
    }

    public static func preferred(in remotes: [Remote]) -> CommitWebLink? {
        let ordered = remotes.filter { $0.name == "origin" } + remotes.filter { $0.name != "origin" }
        return ordered.lazy.compactMap { CommitWebLink(remoteURL: $0.fetchURL) }.first
    }

    private struct Location {
        let scheme: String
        let host: String
        let port: Int?
        let path: String
    }

    private static func location(of remote: String) -> Location? {
        if let separator = remote.range(of: "://") {
            let scheme = remote[..<separator.lowerBound].lowercased()
            guard ["http", "https", "ssh", "git", "git+ssh", "ssh+git"].contains(scheme),
                  let components = URLComponents(string: remote), let host = components.host?.lowercased(), !host.isEmpty else { return nil }
            let isWeb = scheme == "http" || scheme == "https"
            return Location(scheme: isWeb ? scheme : "https", host: host, port: isWeb ? components.port : nil, path: components.path)
        }
        guard let colon = remote.firstIndex(of: ":"), !remote.hasPrefix("/"), !remote.hasPrefix(".") else { return nil }
        let authority = remote[..<colon]
        let host = (authority.split(separator: "@").last.map(String.init) ?? "").lowercased()
        guard !host.isEmpty, !host.contains("/") else { return nil }
        return Location(scheme: "https", host: host, port: nil, path: String(remote[remote.index(after: colon)...]))
    }

    private static func host(named name: String) -> Host? {
        if name.contains("github") { return .github }
        if name.contains("gitlab") { return .gitlab }
        if name.contains("bitbucket") { return .bitbucket }
        if name.contains("gitea") || name == "codeberg.org" { return .gitea }
        return nil
    }
}
