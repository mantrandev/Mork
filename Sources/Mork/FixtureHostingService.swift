import MorkDomain
import Foundation

struct FixtureHostingService: HostingServiceProtocol {
    private struct Fixture: Decodable {
        struct User: Decodable {
            let login: String
            let name: String?
        }

        let users: [String: User]
        let repositories: [String]
        let pageSize: Int?
    }

    private let fixture: Fixture?

    init(file: URL) {
        fixture = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(Fixture.self, from: $0) }
    }

    func currentUser(server: AccountServer, credential: AccountCredential) async throws -> AccountUser {
        guard let user = fixture?.users[credential.secret] else { throw AccountError.invalidToken(server.provider) }
        return AccountUser(login: user.login, name: user.name, avatarURL: nil, scopes: nil)
    }

    func repositories(server: AccountServer, credential: AccountCredential, page: URL?) async throws -> HostedRepositoryPage {
        guard let fixture, fixture.users[credential.secret] != nil else { throw AccountError.invalidToken(server.provider) }
        let size = max(fixture.pageSize ?? 50, 1)
        let number = page.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "page" }?.value }.flatMap(Int.init) ?? 1
        let slice = fixture.repositories.dropFirst((number - 1) * size).prefix(size)
        let repositories = slice.map { name in
            HostedRepository(fullName: name, description: nil, isPrivate: false, httpsURL: "https://\(server.host)/\(name).git", sshURL: "git@\(server.host):\(name).git")
        }
        let hasMore = number * size < fixture.repositories.count
        return HostedRepositoryPage(repositories: repositories, next: hasMore ? URL(string: "\(server.apiURL.absoluteString)/fixture?page=\(number + 1)") : nil)
    }

    func addSSHKey(server: AccountServer, credential: AccountCredential, title: String, key: String) async throws {
        guard fixture?.users[credential.secret] != nil else { throw AccountError.invalidToken(server.provider) }
    }
}
