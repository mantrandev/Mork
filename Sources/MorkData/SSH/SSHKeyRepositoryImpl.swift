import MorkDomain
import Foundation

enum SSHKeygenParser {
    struct Line: Equatable {
        let bits: Int?
        let fingerprint: String
        let comment: String
        let type: String
    }

    static func parse(_ output: String) -> Line? {
        let line = output.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let parts = line.split(separator: " ", maxSplits: 2).map(String.init)
        guard parts.count == 3, parts[1].contains(":"), let open = parts[2].lastIndex(of: "("), parts[2].hasSuffix(")") else { return nil }
        let type = String(parts[2][parts[2].index(after: open)..<parts[2].index(before: parts[2].endIndex)])
        let comment = parts[2][..<open].trimmingCharacters(in: .whitespaces)
        return Line(bits: Int(parts[0]), fingerprint: parts[1], comment: comment == "no comment" ? "" : comment, type: type)
    }
}

public final class SSHKeyRepositoryImpl: SSHKeyRepositoryProtocol {
    static let keygen = "/usr/bin/ssh-keygen"
    static let ssh = "/usr/bin/ssh"

    private let runner: CommandRunning
    private let askpass: AskpassScripts

    public init(runner: CommandRunning = ProcessCommandRunner(), askpass: AskpassScripts) {
        self.runner = runner
        self.askpass = askpass
    }

    public func keys(in directory: URL) async throws -> [SSHKey] {
        let manager = FileManager.default
        guard let names = try? manager.contentsOfDirectory(atPath: directory.path) else { return [] }
        var keys: [SSHKey] = []
        for name in names where name.hasSuffix(".pub") {
            let file = directory.appendingPathComponent(name)
            let output = try await runner.run(Self.keygen, ["-l", "-f", file.path], environment: [:])
            guard output.exitCode == 0, let line = SSHKeygenParser.parse(output.stdout) else { continue }
            keys.append(SSHKey(
                publicKeyURL: file,
                type: line.type,
                bits: line.bits,
                fingerprint: line.fingerprint,
                comment: line.comment,
                hasPrivateKey: manager.fileExists(atPath: file.deletingPathExtension().path)
            ))
        }
        return keys
    }

    public func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    public func generateKey(_ request: SSHKeyRequest) async throws {
        try FileManager.default.createDirectory(at: request.directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        var arguments = ["-q", "-t", "ed25519", "-C", request.email, "-f", request.privateKeyURL.path]
        var environment: [String: String] = [:]
        if request.passphrase.isEmpty {
            arguments += ["-N", ""]
        } else {
            environment = [
                "SSH_ASKPASS": try askpass.sshAskpass().path,
                "SSH_ASKPASS_REQUIRE": "force",
                "DISPLAY": ProcessInfo.processInfo.environment["DISPLAY"] ?? ":0",
                "MORK_SSH_PASSPHRASE": request.passphrase
            ]
        }
        let output = try await runner.run(Self.keygen, arguments, environment: environment)
        guard output.exitCode == 0 else {
            throw SSHKeyError.commandFailed((output.stderr + output.stdout).trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    public func publicKey(of key: SSHKey) async throws -> String {
        guard key.publicKeyURL.pathExtension == "pub" else { throw SSHKeyError.invalidName(key.publicKeyURL.lastPathComponent) }
        return try String(contentsOf: key.publicKeyURL, encoding: .utf8)
    }

    public func testConnection(_ request: SSHConnectionRequest) async throws -> SSHCommandOutput {
        var arguments = ["-T", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=accept-new", "-o", "ConnectTimeout=10"]
        if let identity = request.identity {
            arguments += ["-i", identity.path, "-o", "IdentitiesOnly=yes"]
        }
        let parts = request.host.split(separator: ":", maxSplits: 1).map(String.init)
        if parts.count == 2 { arguments += ["-p", parts[1]] }
        arguments.append("git@\(parts[0])")
        let output = try await runner.run(Self.ssh, arguments, environment: [:])
        return SSHCommandOutput(exitCode: output.exitCode, output: (output.stderr + output.stdout).trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
