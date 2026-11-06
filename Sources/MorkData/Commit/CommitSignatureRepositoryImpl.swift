import MorkDomain
import Foundation

public final class CommitSignatureRepositoryImpl: CommitSignatureRepositoryProtocol {
    static let statusFormat = "--format=%H%x1f%G?"
    static let detailsFormat = "--format=%G?%x1f%GS%x1f%GK"
    static let allowedSignersKey = "gpg.ssh.allowedSignersFile"
    static let noAllowedSigners = ["-c", "\(allowedSignersKey)=/dev/null"]

    private let executor: GitCommandExecuting

    public init(executor: GitCommandExecuting) {
        self.executor = executor
    }

    public func signatures(of hashes: [String]) async throws -> [String: CommitSignature] {
        guard !hashes.isEmpty else { return [:] }
        let output = try await executor.run(
            try await verificationOptions() + ["log", "--no-walk=unsorted", "--no-show-signature", "--stdin", Self.statusFormat],
            input: hashes.joined(separator: "\n") + "\n",
            kind: .read,
            allowedExitCodes: [0]
        )
        var result: [String: CommitSignature] = [:]
        for line in output.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: GitOutputParser.separator, omittingEmptySubsequences: false)
            guard fields.count == 2, !fields[0].isEmpty else { continue }
            result[String(fields[0])] = CommitSignature(code: String(fields[1]))
        }
        return result
    }

    public func signatureDetails(of hash: String) async throws -> CommitSignatureDetails {
        let output = try await executor.read(try await verificationOptions() + ["show", "-s", "--no-show-signature", Self.detailsFormat, hash])
        let fields = output.trimmingCharacters(in: .newlines).split(separator: GitOutputParser.separator, omittingEmptySubsequences: false).map(String.init)
        return CommitSignatureDetails(
            status: CommitSignature(code: fields.first ?? ""),
            signer: fields.count > 1 ? fields[1] : "",
            key: fields.count > 2 ? fields[2] : ""
        )
    }

    private func verificationOptions() async throws -> [String] {
        let configured = try await executor.read(["config", "--get", Self.allowedSignersKey], allowedExitCodes: [0, 1])
        return configured.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Self.noAllowedSigners : []
    }
}
