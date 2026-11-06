import Foundation

public protocol RequestDeviceCodeUseCaseProtocol: Sendable {
    func execute(provider: AccountProvider, address: String) async throws -> DeviceFlowSession
}

public protocol CompleteDeviceFlowUseCaseProtocol: Sendable {
    func execute(_ session: DeviceFlowSession) async throws -> Account
}

public final class RequestDeviceCodeUseCase: RequestDeviceCodeUseCaseProtocol {
    private let store: AccountStoreProtocol
    private let service: DeviceFlowServiceProtocol

    public init(store: AccountStoreProtocol, service: DeviceFlowServiceProtocol) {
        self.store = store
        self.service = service
    }

    public func execute(provider: AccountProvider, address: String) async throws -> DeviceFlowSession {
        guard provider.supportsDeviceFlow, let clientID = store.preferences().clientID(for: provider) else {
            throw AccountError.deviceFlowUnavailable(provider)
        }
        let server = try AccountServer.make(provider: provider, address: address)
        let authorization = try await service.requestCode(server: server, clientID: clientID)
        return DeviceFlowSession(server: server, clientID: clientID, authorization: authorization)
    }
}

public final class CompleteDeviceFlowUseCase: CompleteDeviceFlowUseCaseProtocol {
    public static let slowDownStep = 5

    private let service: DeviceFlowServiceProtocol
    private let addAccount: AddAccountUseCaseProtocol
    private let sleep: @Sendable (Duration) async throws -> Void

    public init(
        service: DeviceFlowServiceProtocol,
        addAccount: AddAccountUseCaseProtocol,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.service = service
        self.addAccount = addAccount
        self.sleep = sleep
    }

    public func execute(_ session: DeviceFlowSession) async throws -> Account {
        var interval = max(session.authorization.interval, 1)
        var waited = 0
        while true {
            guard waited + interval <= session.authorization.expiresIn else { throw AccountError.deviceCodeExpired }
            try await sleep(.seconds(interval))
            waited += interval
            switch try await service.pollToken(server: session.server, clientID: session.clientID, deviceCode: session.authorization.deviceCode) {
            case .pending:
                continue
            case let .slowDown(serverInterval):
                interval = serverInterval ?? interval + Self.slowDownStep
            case .denied:
                throw AccountError.deviceAccessDenied
            case .expired:
                throw AccountError.deviceCodeExpired
            case let .token(token):
                let signIn = AccountSignIn(
                    provider: session.server.provider,
                    address: session.server.provider.acceptsCustomHost ? "https://\(session.server.displayName)" : "",
                    username: "",
                    secret: token,
                    gitUsername: session.server.provider == .gitlab ? "oauth2" : nil
                )
                return try await addAccount.execute(signIn)
            }
        }
    }
}
