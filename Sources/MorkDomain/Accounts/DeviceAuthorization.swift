import Foundation

public struct DeviceAuthorization: Equatable, Sendable {
    public let deviceCode: String
    public let userCode: String
    public let verificationURL: URL
    public let expiresIn: Int
    public let interval: Int

    public init(deviceCode: String, userCode: String, verificationURL: URL, expiresIn: Int, interval: Int) {
        self.deviceCode = deviceCode
        self.userCode = userCode
        self.verificationURL = verificationURL
        self.expiresIn = expiresIn
        self.interval = interval
    }
}

public struct DeviceFlowSession: Equatable, Sendable {
    public let server: AccountServer
    public let clientID: String
    public let authorization: DeviceAuthorization

    public init(server: AccountServer, clientID: String, authorization: DeviceAuthorization) {
        self.server = server
        self.clientID = clientID
        self.authorization = authorization
    }
}

public enum DeviceTokenResponse: Equatable, Sendable {
    case pending
    case slowDown(interval: Int?)
    case denied
    case expired
    case token(String)
}
