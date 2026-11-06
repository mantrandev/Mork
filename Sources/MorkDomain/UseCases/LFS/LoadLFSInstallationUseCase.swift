import Foundation

public protocol LoadLFSInstallationUseCaseProtocol: Sendable {
    func execute() async -> LFSInstallation
}

public final class LoadLFSInstallationUseCase: LoadLFSInstallationUseCaseProtocol {
    private let lfs: LFSRepositoryProtocol
    private let cache = LFSInstallationCache()

    public init(lfs: LFSRepositoryProtocol) {
        self.lfs = lfs
    }

    public func execute() async -> LFSInstallation {
        let lfs = lfs
        return await cache.value {
            guard let version = try? await lfs.version(), !version.isEmpty else { return .notInstalled }
            return .installed(version: version)
        }
    }
}

private actor LFSInstallationCache {
    private var task: Task<LFSInstallation, Never>?

    func value(_ load: @escaping @Sendable () async -> LFSInstallation) async -> LFSInstallation {
        if let task { return await task.value }
        let task = Task { await load() }
        self.task = task
        let value = await task.value
        if !value.isInstalled, self.task == task { self.task = nil }
        return value
    }
}
