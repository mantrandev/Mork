import Foundation

public protocol LoadCommitSignaturesUseCaseProtocol: Sendable {
    func execute(hashes: [String]) async throws -> [String: CommitSignature]
}

public final class LoadCommitSignaturesUseCase: LoadCommitSignaturesUseCaseProtocol {
    public static let batchLimit = 100

    private let signatures: CommitSignatureRepositoryProtocol

    public init(signatures: CommitSignatureRepositoryProtocol) {
        self.signatures = signatures
    }

    public func execute(hashes: [String]) async throws -> [String: CommitSignature] {
        var seen = Set<String>()
        let unique = hashes.filter { !$0.isEmpty && seen.insert($0).inserted }
        var result: [String: CommitSignature] = [:]
        var start = 0
        while start < unique.count {
            let batch = Array(unique[start..<min(start + Self.batchLimit, unique.count)])
            result.merge(try await signatures.signatures(of: batch)) { _, new in new }
            start += Self.batchLimit
        }
        return result
    }
}
