import Foundation

public protocol SearchCommitsUseCaseProtocol: Sendable {
    func execute(query: CommitSearchQuery, options: HistoryOptions, limit: Int) async throws -> [GraphRow]
}

public final class SearchCommitsUseCase: SearchCommitsUseCaseProtocol {
    private let search: CommitSearchRepositoryProtocol

    public init(search: CommitSearchRepositoryProtocol) {
        self.search = search
    }

    public func execute(query: CommitSearchQuery, options: HistoryOptions, limit: Int) async throws -> [GraphRow] {
        guard !query.isEmpty else { return [] }
        let commits = try await search.search(try Self.validated(query), options: options, limit: limit)
        return CommitGraphLayout.layout(commits)
    }

    private static func validated(_ query: CommitSearchQuery) throws -> CommitSearchQuery {
        let term = query.term
        switch query.mode {
        case .regex:
            guard (try? NSRegularExpression(pattern: term)) != nil else { throw CommitSearchError.invalidRegex(pattern: term) }
            return CommitSearchQuery(mode: .regex, text: term)
        case .hash:
            let prefix = term.lowercased()
            guard prefix.allSatisfy(\.isHexDigit) else { throw CommitSearchError.invalidHashPrefix(term) }
            return CommitSearchQuery(mode: .hash, text: prefix)
        case .message, .author, .content:
            return CommitSearchQuery(mode: query.mode, text: term)
        }
    }
}
