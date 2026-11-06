import MorkDomain
import Foundation

public enum LinkHeader {
    public static func next(in header: String?) -> URL? {
        guard let header else { return nil }
        for part in header.split(separator: ",") {
            let pieces = part.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            guard let target = pieces.first, target.hasPrefix("<"), target.hasSuffix(">"),
                  pieces.dropFirst().contains(where: { $0.replacingOccurrences(of: " ", with: "") == "rel=\"next\"" }) else { continue }
            return URL(string: String(target.dropFirst().dropLast()))
        }
        return nil
    }
}

struct HTTPResult {
    let status: Int
    let headers: [AnyHashable: Any]
    let data: Data

    func header(_ name: String) -> String? {
        headers.first { ($0.key as? String)?.caseInsensitiveCompare(name) == .orderedSame }?.value as? String
    }

    func json<Value: Decodable>(_ type: Value.Type) throws -> Value {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw AccountError.unexpectedResponse(status: status)
        }
    }

    var message: String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return "" }
        if let message = object["message"] as? String { return message }
        if let error = object["error"] as? String { return error }
        if let error = object["error"] as? [String: Any], let message = error["message"] as? String { return message }
        return ""
    }
}

enum HostingAuthorization {
    case bearer(String)
    case token(String)
    case basic(username: String, password: String)

    var header: String {
        switch self {
        case let .bearer(secret): "Bearer \(secret)"
        case let .token(secret): "token \(secret)"
        case let .basic(username, password): "Basic " + Data("\(username):\(password)".utf8).base64EncodedString()
        }
    }
}

struct HostingHTTP: Sendable {
    let session: URLSession

    func send(_ url: URL, method: String = "GET", authorization: HostingAuthorization?, accept: String = "application/json", json: [String: String]? = nil, form: [String: String]? = nil) async throws -> HTTPResult {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = method
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue("Mork", forHTTPHeaderField: "User-Agent")
        if let authorization { request.setValue(authorization.header, forHTTPHeaderField: "Authorization") }
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        }
        if let form {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data(Self.encode(form).utf8)
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw AccountError.unexpectedResponse(status: 0) }
            return HTTPResult(status: http.statusCode, headers: http.allHeaderFields, data: data)
        } catch let error as AccountError {
            throw error
        } catch let error as URLError {
            throw AccountError.network(error.localizedDescription)
        } catch {
            throw AccountError.network(String(describing: type(of: error)))
        }
    }

    static func encode(_ form: [String: String]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return form.sorted { $0.key < $1.key }.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value)"
        }.joined(separator: "&")
    }

    static func check(_ result: HTTPResult, provider: AccountProvider, neededScopes: [String] = []) throws {
        switch result.status {
        case 200..<300:
            return
        case 401:
            throw AccountError.invalidToken(provider)
        case 429:
            throw AccountError.rateLimited(resetAt: resetDate(result))
        case 403:
            if result.header("X-RateLimit-Remaining") == "0" || result.header("RateLimit-Remaining") == "0" {
                throw AccountError.rateLimited(resetAt: resetDate(result))
            }
            if let accepted = result.header("X-Accepted-OAuth-Scopes").map(AccountScopes.parse), let fallback = accepted.last {
                let granted = result.header("X-OAuth-Scopes").map(AccountScopes.parse) ?? []
                if accepted.allSatisfy({ !AccountScopes.missing([$0], granted: granted).isEmpty }) {
                    throw AccountError.missingScopes(neededScopes.isEmpty ? [fallback] : neededScopes, provider)
                }
            }
            if !neededScopes.isEmpty, result.message.contains("scope") {
                throw AccountError.missingScopes(neededScopes, provider)
            }
            throw AccountError.forbidden(result.message)
        default:
            throw AccountError.unexpectedResponse(status: result.status)
        }
    }

    private static func resetDate(_ result: HTTPResult) -> Date? {
        if let reset = result.header("X-RateLimit-Reset").flatMap(TimeInterval.init) ?? result.header("RateLimit-Reset").flatMap(TimeInterval.init) {
            return Date(timeIntervalSince1970: reset)
        }
        if let retry = result.header("Retry-After").flatMap(TimeInterval.init) {
            return Date(timeIntervalSinceNow: retry)
        }
        return nil
    }
}
