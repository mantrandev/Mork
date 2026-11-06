import MorkData
import Foundation

enum AppEnvironment: Equatable {
    case development
    case production

    static let current = AppEnvironment(bundleIdentifier: Bundle.main.bundleIdentifier)

    init(bundleIdentifier: String?) {
        self = bundleIdentifier?.hasSuffix(".dev") == true ? .development : .production
    }

    var dataFolder: String {
        switch self {
        case .development: "mork-dev"
        case .production: "mork"
        }
    }

    var keychainPrefix: String {
        switch self {
        case .development: KeychainSecretStore.defaultServicePrefix + ".dev"
        case .production: KeychainSecretStore.defaultServicePrefix
        }
    }
}
