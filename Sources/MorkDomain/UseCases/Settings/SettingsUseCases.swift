import Foundation

public protocol LoadSettingsUseCaseProtocol: Sendable {
    func execute() -> AppSettings
}

public protocol SaveSettingsUseCaseProtocol: Sendable {
    @discardableResult
    func execute(_ settings: AppSettings) -> AppSettings
}

public final class LoadSettingsUseCase: LoadSettingsUseCaseProtocol {
    private let store: SettingsRepositoryProtocol

    public init(store: SettingsRepositoryProtocol) {
        self.store = store
    }

    public func execute() -> AppSettings {
        (store.load() ?? .standard).normalized()
    }
}

public final class SaveSettingsUseCase: SaveSettingsUseCaseProtocol {
    private let store: SettingsRepositoryProtocol

    public init(store: SettingsRepositoryProtocol) {
        self.store = store
    }

    @discardableResult
    public func execute(_ settings: AppSettings) -> AppSettings {
        let normalized = settings.normalized()
        store.save(normalized)
        return normalized
    }
}
