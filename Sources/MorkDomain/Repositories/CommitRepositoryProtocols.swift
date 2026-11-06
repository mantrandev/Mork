import Foundation

public protocol CommitTemplateRepositoryProtocol: Sendable {
    func template() async throws -> CommitTemplate?
}

public protocol SigningKeyRepositoryProtocol: Sendable {
    func gpgKeys() async throws -> [SigningKey]
    func sshKeys() async throws -> [SigningKey]
}

public protocol CommitMessageRepositoryProtocol: Sendable {
    func messages(of hashes: [String]) async throws -> [String: String]
}

public protocol CommitSignatureRepositoryProtocol: Sendable {
    func signatures(of hashes: [String]) async throws -> [String: CommitSignature]
    func signatureDetails(of hash: String) async throws -> CommitSignatureDetails
}
