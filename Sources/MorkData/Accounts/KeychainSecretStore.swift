import MorkDomain
import Foundation
import Security

public final class KeychainSecretStore: AccountSecretStoreProtocol {
    public static let defaultServicePrefix = "dev.mantrandev.mork"
    private static let queue = DispatchQueue(label: "mork.keychain", qos: .userInitiated)

    private struct Item: Sendable {
        let service: String
        let account: String
        let label: String

        func query(_ extra: [String: Any] = [:]) -> CFDictionary {
            let base: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecAttrSynchronizable as String: false
            ]
            return base.merging(extra) { _, new in new } as CFDictionary
        }
    }

    private let servicePrefix: String

    public init(servicePrefix: String = KeychainSecretStore.defaultServicePrefix) {
        self.servicePrefix = servicePrefix
    }

    public func service(for account: Account) -> String {
        "\(servicePrefix) \(account.server.displayName) \(account.login.lowercased())"
    }

    public func secret(for account: Account) async throws -> String? {
        let item = item(for: account)
        return try await Self.perform {
            var result: CFTypeRef?
            let status = SecItemCopyMatching(item.query([kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]), &result)
            if status == errSecItemNotFound { return nil }
            guard status == errSecSuccess, let data = result as? Data else { throw AccountError.keychain(status: status) }
            return String(decoding: data, as: UTF8.self)
        }
    }

    public func hasSecret(for account: Account) async -> Bool {
        let item = item(for: account)
        return (try? await Self.perform {
            SecItemCopyMatching(item.query([kSecReturnAttributes as String: true, kSecMatchLimit as String: kSecMatchLimitOne]), nil) == errSecSuccess
        }) ?? false
    }

    public func setSecret(_ secret: String, for account: Account) async throws {
        let item = item(for: account)
        let data = Data(secret.utf8)
        try await Self.perform {
            let update = [kSecValueData as String: data, kSecAttrLabel as String: item.label] as CFDictionary
            var status = SecItemUpdate(item.query(), update)
            if status == errSecItemNotFound {
                status = SecItemAdd(item.query([
                    kSecValueData as String: data,
                    kSecAttrLabel as String: item.label,
                    kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
                ]), nil)
            }
            guard status == errSecSuccess else { throw AccountError.keychain(status: status) }
        }
    }

    public func deleteSecret(for account: Account) async throws {
        let item = item(for: account)
        try await Self.perform {
            let status = SecItemDelete(item.query())
            guard status == errSecSuccess || status == errSecItemNotFound else { throw AccountError.keychain(status: status) }
        }
    }

    private func item(for account: Account) -> Item {
        Item(service: service(for: account), account: account.login.lowercased(), label: "Mork: \(account.login) on \(account.server.displayName)")
    }

    private static func perform<Value: Sendable>(_ work: @escaping @Sendable () throws -> Value) async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { continuation.resume(with: Result(catching: work)) }
        }
    }
}
