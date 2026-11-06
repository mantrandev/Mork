import Foundation

public protocol LoadAuthorAvatarUseCaseProtocol: Sendable {
    func execute(email: String) async -> Data?
}

public final class LoadAuthorAvatarUseCase: LoadAuthorAvatarUseCaseProtocol {
    private let avatars: AuthorAvatarRepositoryProtocol

    public init(avatars: AuthorAvatarRepositoryProtocol) {
        self.avatars = avatars
    }

    public func execute(email: String) async -> Data? {
        try? await avatars.avatar(forEmail: email)
    }
}
