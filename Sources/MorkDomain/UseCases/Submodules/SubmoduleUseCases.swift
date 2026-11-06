import Foundation

public protocol UpdateSubmodulesUseCaseProtocol: Sendable {
    func execute(progress: @escaping @Sendable (String) -> Void) async throws
}

public protocol AddSubmoduleUseCaseProtocol: Sendable {
    func execute(url: String, path: String) async throws
}

public protocol SyncSubmodulesUseCaseProtocol: Sendable {
    func execute() async throws
}

public final class UpdateSubmodulesUseCase: UpdateSubmodulesUseCaseProtocol {
    private let submodules: SubmoduleRepositoryProtocol

    public init(submodules: SubmoduleRepositoryProtocol) {
        self.submodules = submodules
    }

    public func execute(progress: @escaping @Sendable (String) -> Void) async throws {
        try await submodules.updateSubmodules(progress: progress)
    }
}

public final class AddSubmoduleUseCase: AddSubmoduleUseCaseProtocol {
    private let submodules: SubmoduleRepositoryProtocol

    public init(submodules: SubmoduleRepositoryProtocol) {
        self.submodules = submodules
    }

    public func execute(url: String, path: String) async throws {
        let url = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { throw SubmoduleError.emptyURL }
        guard !path.isEmpty else { throw SubmoduleError.emptyPath }
        let components = path.split(whereSeparator: { $0 == "/" || $0 == "\\" })
        guard !path.hasPrefix("/"), !path.hasPrefix("-"), !components.contains("..") else { throw SubmoduleError.invalidPath(path) }
        try await submodules.addSubmodule(url: url, path: path)
    }
}

public final class SyncSubmodulesUseCase: SyncSubmodulesUseCaseProtocol {
    private let submodules: SubmoduleRepositoryProtocol

    public init(submodules: SubmoduleRepositoryProtocol) {
        self.submodules = submodules
    }

    public func execute() async throws {
        try await submodules.syncSubmodules()
    }
}
