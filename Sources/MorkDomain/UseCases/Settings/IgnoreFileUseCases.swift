import Foundation

public protocol LoadIgnoreFileUseCaseProtocol: Sendable {
    func execute() async throws -> IgnoreFileDocument
}

public protocol SaveIgnoreFileUseCaseProtocol: Sendable {
    @discardableResult
    func execute(text: String, document: IgnoreFileDocument) async throws -> IgnoreFileDocument
}

public final class LoadIgnoreFileUseCase: LoadIgnoreFileUseCaseProtocol {
    private let ignore: IgnoreRepositoryProtocol

    public init(ignore: IgnoreRepositoryProtocol) {
        self.ignore = ignore
    }

    public func execute() async throws -> IgnoreFileDocument {
        IgnoreFileDocument(contents: try await ignore.contents(of: .gitignore))
    }
}

public final class SaveIgnoreFileUseCase: SaveIgnoreFileUseCaseProtocol {
    private let ignore: IgnoreRepositoryProtocol

    public init(ignore: IgnoreRepositoryProtocol) {
        self.ignore = ignore
    }

    @discardableResult
    public func execute(text: String, document: IgnoreFileDocument) async throws -> IgnoreFileDocument {
        let contents = document.serialized(text)
        try await ignore.write(contents, to: .gitignore)
        return IgnoreFileDocument(contents: contents)
    }
}
