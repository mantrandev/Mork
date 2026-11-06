import MorkDomain
import CryptoKit
import Foundation

public final class AvatarCacheImpl: AvatarRepositoryProtocol {
    public static let maximumSize = 2 << 20

    private let directory: URL
    private let session: URLSession

    public init(directory: URL, session: URLSession = URLSession(configuration: .ephemeral)) {
        self.directory = directory
        self.session = session
    }

    public func avatar(at url: URL) async throws -> Data {
        guard url.scheme == "https" else { throw AccountError.forbidden("Avatars load over https only.") }
        let file = directory.appendingPathComponent(Self.fileName(for: url))
        if let cached = try? Data(contentsOf: file) { return cached }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw AccountError.network((error as? URLError)?.localizedDescription ?? "avatar download failed")
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), !data.isEmpty, data.count <= Self.maximumSize else {
            throw AccountError.unexpectedResponse(status: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: file, options: .atomic)
        return data
    }

    static func fileName(for url: URL) -> String {
        SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
