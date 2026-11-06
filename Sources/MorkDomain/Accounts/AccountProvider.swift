import Foundation

public enum AccountProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case github
    case githubEnterprise
    case gitlab
    case bitbucket
    case gitea

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .github: "GitHub"
        case .githubEnterprise: "GitHub Enterprise"
        case .gitlab: "GitLab"
        case .bitbucket: "Bitbucket Cloud"
        case .gitea: "Gitea"
        }
    }

    public var defaultHost: String? {
        switch self {
        case .github: "github.com"
        case .gitlab: "gitlab.com"
        case .bitbucket: "bitbucket.org"
        case .githubEnterprise, .gitea: nil
        }
    }

    public var acceptsCustomHost: Bool {
        switch self {
        case .githubEnterprise, .gitlab, .gitea: true
        case .github, .bitbucket: false
        }
    }

    public var needsUsername: Bool { self == .bitbucket }

    public var secretTitle: String { self == .bitbucket ? "API token or app password" : "Personal access token" }

    public var supportsDeviceFlow: Bool { self == .github || self == .gitlab }

    public var supportsSSHKeyUpload: Bool {
        switch self {
        case .github, .githubEnterprise, .gitlab: true
        case .bitbucket, .gitea: false
        }
    }

    public var requiredScopes: [String] {
        switch self {
        case .github, .githubEnterprise: ["repo"]
        case .gitlab, .bitbucket, .gitea: []
        }
    }

    public var sshKeyScopes: [String] {
        switch self {
        case .github, .githubEnterprise: ["write:public_key"]
        case .gitlab: ["api"]
        case .bitbucket, .gitea: []
        }
    }

    public var scopeHint: String {
        switch self {
        case .github, .githubEnterprise:
            "Create a classic token with these scopes: repo (clone, fetch and push private repositories), read:user (your name and avatar), admin:public_key (only for Add to account in the SSH tab)."
        case .gitlab:
            "Create a token with these scopes: read_user (your name and avatar), write_repository (clone, fetch and push), api (lists your projects and lets the SSH tab add keys)."
        case .bitbucket:
            "Create an API token with the scopes read:user:bitbucket, read:repository:bitbucket and write:repository:bitbucket, and sign in with your Atlassian account email. An older app password (Account: Read, Repositories: Read and Write) signs in with your Bitbucket username."
        case .gitea:
            "Create a token with read:user and write:repository. Gitea needs write:user to add SSH keys, which Mork does not do yet."
        }
    }

    func apiURL(host: String, path: String) -> URL {
        switch self {
        case .github: URL(string: "https://api.github.com")!
        case .bitbucket: URL(string: "https://api.bitbucket.org/2.0")!
        case .githubEnterprise: URL(string: "https://\(host)\(path)/api/v3")!
        case .gitlab: URL(string: "https://\(host)\(path)/api/v4")!
        case .gitea: URL(string: "https://\(host)\(path)/api/v1")!
        }
    }

    func tokenPageURL(web: String) -> URL {
        switch self {
        case .github, .githubEnterprise:
            URL(string: "\(web)/settings/tokens/new?scopes=repo,read:user,admin:public_key&description=Mork")!
        case .gitlab:
            URL(string: "\(web)/-/user_settings/personal_access_tokens?name=Mork&scopes=api,read_user,write_repository")!
        case .bitbucket:
            URL(string: "https://id.atlassian.com/manage-profile/security/api-tokens")!
        case .gitea:
            URL(string: "\(web)/user/settings/applications")!
        }
    }
}

public enum AccountScopes {
    private static let implied: [String: Set<String>] = [
        "repo": ["public_repo", "repo:status", "repo_deployment", "repo:invite"],
        "user": ["read:user", "user:email", "user:follow"],
        "admin:public_key": ["write:public_key", "read:public_key"],
        "write:public_key": ["read:public_key"]
    ]

    public static func parse(_ header: String) -> [String] {
        header.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    public static func missing(_ required: [String], granted: [String]) -> [String] {
        let effective = granted.reduce(into: Set(granted)) { result, scope in
            result.formUnion(implied[scope] ?? [])
            result.formUnion(implied[scope]?.flatMap { implied[$0] ?? [] } ?? [])
        }
        return required.filter { !effective.contains($0) }
    }
}
