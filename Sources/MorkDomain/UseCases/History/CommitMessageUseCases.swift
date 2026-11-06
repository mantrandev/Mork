import Foundation

public protocol LoadCommitMessagesUseCaseProtocol: Sendable {
    func execute(hashes: [String]) async throws -> [String: String]
}

public final class LoadCommitMessagesUseCase: LoadCommitMessagesUseCaseProtocol {
    public static let batchLimit = 100

    private let messages: CommitMessageRepositoryProtocol

    public init(messages: CommitMessageRepositoryProtocol) {
        self.messages = messages
    }

    public func execute(hashes: [String]) async throws -> [String: String] {
        var seen = Set<String>()
        let unique = hashes.filter { !$0.isEmpty && seen.insert($0).inserted }
        var result: [String: String] = [:]
        var start = 0
        while start < unique.count {
            let batch = Array(unique[start..<min(start + Self.batchLimit, unique.count)])
            result.merge(try await messages.messages(of: batch)) { _, new in new }
            start += Self.batchLimit
        }
        return result
    }
}
