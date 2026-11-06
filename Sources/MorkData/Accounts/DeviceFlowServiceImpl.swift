import MorkDomain
import Foundation

public final class DeviceFlowServiceImpl: DeviceFlowServiceProtocol {
    private static let grantType = "urn:ietf:params:oauth:grant-type:device_code"

    private let http: HostingHTTP

    public init(session: URLSession = URLSession(configuration: .ephemeral)) {
        http = HostingHTTP(session: session)
    }

    public func requestCode(server: AccountServer, clientID: String) async throws -> DeviceAuthorization {
        let endpoints = try Self.endpoints(for: server)
        let result = try await http.send(endpoints.code, method: "POST", authorization: nil, form: ["client_id": clientID, "scope": endpoints.scope])
        guard (200..<300).contains(result.status) else {
            try HostingHTTP.check(result, provider: server.provider)
            throw AccountError.unexpectedResponse(status: result.status)
        }
        let body = try result.json(CodeResponse.self)
        guard let verification = URL(string: body.verification_uri) else { throw AccountError.unexpectedResponse(status: result.status) }
        return DeviceAuthorization(deviceCode: body.device_code, userCode: body.user_code, verificationURL: verification, expiresIn: body.expires_in, interval: body.interval ?? 5)
    }

    public func pollToken(server: AccountServer, clientID: String, deviceCode: String) async throws -> DeviceTokenResponse {
        let endpoints = try Self.endpoints(for: server)
        let result = try await http.send(endpoints.token, method: "POST", authorization: nil, form: ["client_id": clientID, "device_code": deviceCode, "grant_type": Self.grantType])
        guard result.status == 200 || result.status == 400 || result.status == 401 else {
            throw AccountError.unexpectedResponse(status: result.status)
        }
        let body = try result.json(TokenResponse.self)
        if let token = body.access_token { return .token(token) }
        switch body.error {
        case "authorization_pending": return .pending
        case "slow_down": return .slowDown(interval: body.interval)
        case "access_denied": return .denied
        case "expired_token": return .expired
        default: throw AccountError.forbidden(body.error_description ?? body.error ?? "Unknown device flow error.")
        }
    }

    private static func endpoints(for server: AccountServer) throws -> (code: URL, token: URL, scope: String) {
        switch server.provider {
        case .github:
            (URL(string: "https://github.com/login/device/code")!, URL(string: "https://github.com/login/oauth/access_token")!, "repo read:user admin:public_key")
        case .gitlab:
            (server.webURL.appendingPathComponent("oauth/authorize_device"), server.webURL.appendingPathComponent("oauth/token"), "api read_user write_repository")
        case .githubEnterprise, .bitbucket, .gitea:
            throw AccountError.deviceFlowUnavailable(server.provider)
        }
    }
}

private struct CodeResponse: Decodable {
    let device_code: String
    let user_code: String
    let verification_uri: String
    let expires_in: Int
    let interval: Int?
}

private struct TokenResponse: Decodable {
    let access_token: String?
    let error: String?
    let error_description: String?
    let interval: Int?
}
