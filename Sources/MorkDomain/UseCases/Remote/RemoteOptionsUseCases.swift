import Foundation

public protocol LoadRemotesUseCaseProtocol: Sendable {
    func execute() async throws -> [String]
}

public protocol LoadPullModeUseCaseProtocol: Sendable {
    func execute() -> PullMode
}

public protocol PullBranchWithModeUseCaseProtocol: Sendable {
    func execute(branch: Branch?, mode: PullMode) async throws
}

public protocol PullBranchWithOptionsUseCaseProtocol: Sendable {
    func execute(branch: Branch?, options: PullOptions) async throws
}

public protocol LoadPullAutostashUseCaseProtocol: Sendable {
    func execute() -> Bool
}

public protocol PushBranchWithOptionsUseCaseProtocol: Sendable {
    func execute(branch: Branch?, remote: String, includeTags: Bool, forceWithLease: Bool) async throws
}

public final class LoadRemotesUseCase: LoadRemotesUseCaseProtocol {
    private let remote: RemoteRepositoryProtocol

    public init(remote: RemoteRepositoryProtocol) {
        self.remote = remote
    }

    public func execute() async throws -> [String] {
        try await remote.remotes()
    }
}

public final class LoadPullModeUseCase: LoadPullModeUseCaseProtocol {
    private let preferences: PullPreferencesRepositoryProtocol
    private let repository: URL
    private let settings: SettingsRepositoryProtocol?

    public init(preferences: PullPreferencesRepositoryProtocol, repository: URL, settings: SettingsRepositoryProtocol? = nil) {
        self.preferences = preferences
        self.repository = repository
        self.settings = settings
    }

    public func execute() -> PullMode {
        preferences.pullMode(for: repository) ?? settings?.load()?.defaultPullMode ?? .default
    }
}

public final class PullBranchWithModeUseCase: PullBranchWithModeUseCaseProtocol {
    private let remote: RemoteRepositoryProtocol
    private let preferences: PullPreferencesRepositoryProtocol
    private let repository: URL

    public init(remote: RemoteRepositoryProtocol, preferences: PullPreferencesRepositoryProtocol, repository: URL) {
        self.remote = remote
        self.preferences = preferences
        self.repository = repository
    }

    public func execute(branch: Branch?, mode: PullMode) async throws {
        guard branch != nil else { throw GitDomainError.detachedHead }
        guard try await !remote.remotes().isEmpty else { throw GitDomainError.noRemote }
        preferences.savePullMode(mode, for: repository)
        try await remote.pull(mode: mode)
    }
}

public final class PullBranchWithOptionsUseCase: PullBranchWithOptionsUseCaseProtocol {
    private let remote: RemoteRepositoryProtocol
    private let preferences: PullPreferencesRepositoryProtocol
    private let repository: URL

    public init(remote: RemoteRepositoryProtocol, preferences: PullPreferencesRepositoryProtocol, repository: URL) {
        self.remote = remote
        self.preferences = preferences
        self.repository = repository
    }

    public func execute(branch: Branch?, options: PullOptions) async throws {
        guard branch != nil else { throw GitDomainError.detachedHead }
        guard !options.remote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw GitDomainError.noRemote }
        preferences.savePullMode(options.rebase ? .rebase : .merge, for: repository)
        preferences.saveAutostash(options.autostash, for: repository)
        try await remote.pull(options: options)
    }
}

public final class LoadPullAutostashUseCase: LoadPullAutostashUseCaseProtocol {
    private let preferences: PullPreferencesRepositoryProtocol
    private let repository: URL

    public init(preferences: PullPreferencesRepositoryProtocol, repository: URL) {
        self.preferences = preferences
        self.repository = repository
    }

    public func execute() -> Bool {
        preferences.autostash(for: repository) ?? false
    }
}

public final class PushBranchWithOptionsUseCase: PushBranchWithOptionsUseCaseProtocol {
    private let remote: RemoteRepositoryProtocol

    public init(remote: RemoteRepositoryProtocol) {
        self.remote = remote
    }

    public func execute(branch: Branch?, remote name: String, includeTags: Bool, forceWithLease: Bool) async throws {
        guard let branch else { throw GitDomainError.detachedHead }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw GitDomainError.noRemote }
        try await remote.push(options: PushOptions(branch: branch, remote: name, includeTags: includeTags, forceWithLease: forceWithLease))
    }
}
