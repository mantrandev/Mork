import Foundation

public protocol CloneRepositoryUseCaseProtocol: Sendable {
    func execute(source: String, destination: URL, progress: @escaping @Sendable (String) -> Void) async throws -> URL
}

public final class CloneRepositoryUseCase: CloneRepositoryUseCaseProtocol {
    private static let authenticationMarkers = [
        "Authentication failed", "could not read Username", "could not read Password",
        "terminal prompts disabled", "Permission denied (publickey)", "Host key verification failed"
    ]
    private static let unavailableMarkers = [
        "does not exist", "does not appear to be a git repository", "Could not resolve host", "not found"
    ]

    private let cloner: RepositoryClonerProtocol

    public init(cloner: RepositoryClonerProtocol) {
        self.cloner = cloner
    }

    public func execute(source: String, destination: URL, progress: @escaping @Sendable (String) -> Void) async throws -> URL {
        let source = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { throw CloneError.emptySource }
        guard cloner.isAvailableDestination(destination) else { throw CloneError.destinationNotEmpty(path: destination.path) }
        do {
            try await cloner.clone(from: source, to: destination, progress: progress)
        } catch {
            if case let GitDomainError.commandFailed(_, _, message) = error, let explained = Self.explain(message, source: source) {
                throw explained
            }
            throw error
        }
        return destination
    }

    public static func suggestedDirectoryName(for source: String) -> String {
        var name = source.trimmingCharacters(in: .whitespacesAndNewlines)
        while name.hasSuffix("/") { name.removeLast() }
        if name.hasSuffix(".git") { name.removeLast(4) }
        if let slash = name.lastIndex(of: "/") { name = String(name[name.index(after: slash)...]) }
        if let colon = name.lastIndex(of: ":") { name = String(name[name.index(after: colon)...]) }
        return name
    }

    private static func explain(_ message: String, source: String) -> CloneError? {
        if authenticationMarkers.contains(where: message.contains) {
            return .authenticationFailed(source: source)
        }
        let lines = message.split(whereSeparator: \.isNewline).map(String.init)
        guard let reason = lines.first(where: { line in line.hasPrefix("fatal:") && unavailableMarkers.contains(where: line.contains) }) else {
            return nil
        }
        return .sourceUnavailable(source: source, reason: reason)
    }
}
