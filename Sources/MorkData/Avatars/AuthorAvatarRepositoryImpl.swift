import MorkDomain
import CryptoKit
import Foundation

public final class AuthorAvatarRepositoryImpl: AuthorAvatarRepositoryProtocol {
    public static let maximumSize = 1 << 20
    public static let timeToLive: TimeInterval = 7 * 24 * 60 * 60

    private let directory: URL
    private let session: URLSession
    private let now: @Sendable () -> Date

    public init(directory: URL, session: URLSession = URLSession(configuration: .ephemeral), now: @escaping @Sendable () -> Date = Date.init) {
        self.directory = directory
        self.session = session
        self.now = now
    }

    public func avatar(forEmail email: String) async throws -> Data {
        let candidates = Self.candidates(for: email).filter { $0.scheme == "https" }
        guard !candidates.isEmpty else { throw AuthorAvatarError.notFound }
        let file = directory.appendingPathComponent(Self.fileName(for: AvatarLocator.normalizedEmail(email)))
        let cached = cachedFile(at: file)
        if let cached, cached.isFresh { return cached.data }
        var failure = AuthorAvatarError.notFound
        for url in candidates {
            switch await download(url) {
            case let .success(data):
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try? data.write(to: file, options: .atomic)
                return data
            case .failure(.notFound):
                continue
            case let .failure(error):
                failure = error
            }
        }
        if let cached { return cached.data }
        throw failure
    }

    static func candidates(for email: String) -> [URL] {
        AvatarLocator.candidates(for: email, md5: md5)
    }

    static func md5(_ text: String) -> String {
        Insecure.MD5.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func fileName(for email: String) -> String {
        SHA256.hash(data: Data(email.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func cachedFile(at file: URL) -> (data: Data, isFresh: Bool)? {
        guard let data = try? Data(contentsOf: file), !data.isEmpty else { return nil }
        let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        return (data, now().timeIntervalSince(modified) < Self.timeToLive)
    }

    private func download(_ url: URL) async -> Result<Data, AuthorAvatarError> {
        guard let (data, response) = try? await session.data(from: url), let http = response as? HTTPURLResponse else {
            return .failure(.unavailable)
        }
        if http.statusCode == 404 { return .failure(.notFound) }
        guard (200..<300).contains(http.statusCode), !data.isEmpty, data.count <= Self.maximumSize else {
            return .failure(.unavailable)
        }
        return .success(data)
    }
}
