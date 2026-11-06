import MorkDomain
import Foundation

public final class SigningKeyRepositoryImpl: SigningKeyRepositoryProtocol {
    public static let gpgLocations = ["/opt/homebrew/bin/gpg", "/usr/local/bin/gpg", "/usr/local/MacGPG2/bin/gpg", "/opt/local/bin/gpg"]
    static let maximumPublicKeySize = 16_384

    private let runner: CommandRunning
    private let sshDirectory: URL
    private let gpgCandidates: [String]

    public init(
        runner: CommandRunning = ProcessCommandRunner(),
        sshDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh"),
        gpgCandidates: [String] = SigningKeyRepositoryImpl.gpgLocations
    ) {
        self.runner = runner
        self.sshDirectory = sshDirectory
        self.gpgCandidates = gpgCandidates
    }

    public var gpgPath: String? {
        gpgCandidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public func gpgKeys() async throws -> [SigningKey] {
        guard let gpg = gpgPath else { return [] }
        let output = try await runner.run(gpg, ["--list-secret-keys", "--with-colons"], environment: [:])
        guard output.exitCode == 0 else { return [] }
        return GPGKeyListParser.secretSigningKeys(output.stdout)
    }

    public func sshKeys() async throws -> [SigningKey] {
        let manager = FileManager.default
        guard let names = try? manager.contentsOfDirectory(atPath: sshDirectory.path) else { return [] }
        return names.filter { $0.hasSuffix(".pub") }.sorted().compactMap { name in
            let file = sshDirectory.appendingPathComponent(name)
            guard let size = (try? manager.attributesOfItem(atPath: file.path))?[.size] as? Int, size <= Self.maximumPublicKeySize,
                  let contents = try? String(contentsOf: file, encoding: .utf8)
            else { return nil }
            return SSHPublicKeyParser.key(path: file.path, contents: contents)
        }
    }
}
