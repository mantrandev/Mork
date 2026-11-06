import MorkDomain
import Foundation

extension HistoryRepositoryImpl: CommitMessageRepositoryProtocol {
    static let messageFormat = "--format=%H%x1f%B%x1e"

    public func messages(of hashes: [String]) async throws -> [String: String] {
        guard !hashes.isEmpty else { return [:] }
        let output = try await executor.run(
            ["log", "--no-walk=unsorted", "--no-show-signature", "--stdin", Self.messageFormat],
            input: hashes.joined(separator: "\n") + "\n",
            kind: .read,
            allowedExitCodes: [0]
        )
        var result: [String: String] = [:]
        for record in output.split(separator: GitOutputParser.recordSeparator) {
            let trimmed = record.drop { $0.isNewline }
            let fields = trimmed.split(separator: GitOutputParser.separator, maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2, !fields[0].isEmpty else { continue }
            result[String(fields[0])] = String(fields[1]).trimmingCharacters(in: .newlines)
        }
        return result
    }
}
