import MorkDomain
import Foundation

public final class HostingServiceImpl: HostingServiceProtocol {
    private let http: HostingHTTP

    public init(session: URLSession = URLSession(configuration: .ephemeral)) {
        http = HostingHTTP(session: session)
    }

    public func currentUser(server: AccountServer, credential: AccountCredential) async throws -> AccountUser {
        let result = try await get(server.apiURL.appendingPathComponent("user"), server: server, credential: credential)
        switch server.provider {
        case .github, .githubEnterprise:
            let user = try result.json(GitHubUser.self)
            return AccountUser(login: user.login, name: user.name, avatarURL: user.avatar_url.flatMap(URL.init), scopes: result.header("X-OAuth-Scopes").map(AccountScopes.parse))
        case .gitlab:
            let user = try result.json(GitLabUser.self)
            return AccountUser(login: user.username, name: user.name, avatarURL: user.avatar_url.flatMap(URL.init), scopes: nil)
        case .bitbucket:
            let user = try result.json(BitbucketUser.self)
            return AccountUser(login: user.username ?? user.nickname ?? credential.username, name: user.display_name, avatarURL: user.links?.avatar?.href.flatMap(URL.init), scopes: nil)
        case .gitea:
            let user = try result.json(GiteaUser.self)
            return AccountUser(login: user.login, name: user.full_name.flatMap { $0.isEmpty ? nil : $0 }, avatarURL: user.avatar_url.flatMap(URL.init), scopes: nil)
        }
    }

    public func repositories(server: AccountServer, credential: AccountCredential, page: URL?) async throws -> HostedRepositoryPage {
        let url = try page.map { try sameHost($0, as: server) } ?? firstPage(server)
        let result = try await get(url, server: server, credential: credential)
        let repositories: [HostedRepository]
        var next = LinkHeader.next(in: result.header("Link"))
        switch server.provider {
        case .github, .githubEnterprise, .gitea:
            repositories = try result.json([GitHubRepository].self).map {
                HostedRepository(fullName: $0.full_name, description: Self.text($0.description), isPrivate: $0.private ?? false, httpsURL: $0.clone_url, sshURL: $0.ssh_url)
            }
        case .gitlab:
            repositories = try result.json([GitLabProject].self).map {
                HostedRepository(fullName: $0.path_with_namespace, description: Self.text($0.description), isPrivate: $0.visibility != "public", httpsURL: $0.http_url_to_repo, sshURL: $0.ssh_url_to_repo)
            }
        case .bitbucket:
            let body = try result.json(BitbucketPage.self)
            next = body.next.flatMap(URL.init)
            repositories = body.values.map { repository in
                let clone = repository.links?.clone ?? []
                return HostedRepository(
                    fullName: repository.full_name,
                    description: Self.text(repository.description),
                    isPrivate: repository.is_private ?? false,
                    httpsURL: clone.first { $0.name == "https" }?.href ?? "",
                    sshURL: clone.first { $0.name == "ssh" }?.href ?? ""
                )
            }
        }
        return HostedRepositoryPage(repositories: repositories, next: next.flatMap { try? sameHost($0, as: server) })
    }

    public func addSSHKey(server: AccountServer, credential: AccountCredential, title: String, key: String) async throws {
        guard server.provider.supportsSSHKeyUpload else { throw SSHKeyError.uploadUnsupported(server.provider) }
        let result = try await http.send(
            server.apiURL.appendingPathComponent("user/keys"),
            method: "POST",
            authorization: authorization(server, credential),
            accept: accept(server),
            json: ["title": title, "key": key]
        )
        if result.status == 422 || result.status == 400 {
            let body = String(decoding: result.data, as: UTF8.self)
            if body.contains("already in use") || body.contains("already been taken") { throw AccountError.sshKeyAlreadyAdded }
        }
        try HostingHTTP.check(result, provider: server.provider, neededScopes: server.provider.sshKeyScopes)
    }

    private func get(_ url: URL, server: AccountServer, credential: AccountCredential) async throws -> HTTPResult {
        let result = try await http.send(url, authorization: authorization(server, credential), accept: accept(server))
        try HostingHTTP.check(result, provider: server.provider)
        return result
    }

    private func firstPage(_ server: AccountServer) -> URL {
        let api = server.apiURL
        let (path, query): (String, [URLQueryItem]) = switch server.provider {
        case .github, .githubEnterprise:
            ("user/repos", [.init(name: "per_page", value: "100"), .init(name: "sort", value: "updated"), .init(name: "affiliation", value: "owner,collaborator,organization_member")])
        case .gitlab:
            ("projects", [.init(name: "membership", value: "true"), .init(name: "simple", value: "true"), .init(name: "per_page", value: "100"), .init(name: "order_by", value: "last_activity_at")])
        case .bitbucket:
            ("repositories", [.init(name: "role", value: "member"), .init(name: "pagelen", value: "100"), .init(name: "sort", value: "-updated_on")])
        case .gitea:
            ("user/repos", [.init(name: "limit", value: "50")])
        }
        var components = URLComponents(url: api.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = query
        return components.url!
    }

    private func sameHost(_ url: URL, as server: AccountServer) throws -> URL {
        guard url.scheme == "https", url.host?.lowercased() == server.apiURL.host?.lowercased(), url.port == server.apiURL.port else {
            throw AccountError.forbidden("The next page points to another server, so Mork did not send the token there.")
        }
        return url
    }

    private func authorization(_ server: AccountServer, _ credential: AccountCredential) -> HostingAuthorization {
        switch server.provider {
        case .github, .githubEnterprise, .gitlab: .bearer(credential.secret)
        case .gitea: .token(credential.secret)
        case .bitbucket: .basic(username: credential.username, password: credential.secret)
        }
    }

    private func accept(_ server: AccountServer) -> String {
        server.provider == .github || server.provider == .githubEnterprise ? "application/vnd.github+json" : "application/json"
    }

    private static func text(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}

private struct GitHubUser: Decodable {
    let login: String
    let name: String?
    let avatar_url: String?
}

private struct GitLabUser: Decodable {
    let username: String
    let name: String?
    let avatar_url: String?
}

private struct GiteaUser: Decodable {
    let login: String
    let full_name: String?
    let avatar_url: String?
}

private struct BitbucketUser: Decodable {
    struct Links: Decodable {
        struct Link: Decodable {
            let href: String?
        }

        let avatar: Link?
    }

    let username: String?
    let nickname: String?
    let display_name: String?
    let links: Links?
}

private struct GitHubRepository: Decodable {
    let full_name: String
    let description: String?
    let `private`: Bool?
    let clone_url: String
    let ssh_url: String
}

private struct GitLabProject: Decodable {
    let path_with_namespace: String
    let description: String?
    let visibility: String?
    let http_url_to_repo: String
    let ssh_url_to_repo: String
}

private struct BitbucketPage: Decodable {
    struct Repository: Decodable {
        struct Links: Decodable {
            struct Clone: Decodable {
                let name: String
                let href: String
            }

            let clone: [Clone]?
        }

        let full_name: String
        let description: String?
        let is_private: Bool?
        let links: Links?
    }

    let values: [Repository]
    let next: String?
}
