import Foundation

public enum CloneError: LocalizedError, Sendable, Equatable {
    case emptySource
    case destinationNotEmpty(path: String)
    case authenticationFailed(source: String)
    case sourceUnavailable(source: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .emptySource:
            "Enter the URL or path of the repository to clone."
        case let .destinationNotEmpty(path):
            "\(path) already exists and is not empty. Choose another folder or name."
        case let .authenticationFailed(source):
            "Authentication failed for \(source). Mork cannot ask for passwords: add an account in Settings ▸ Accounts, set up an SSH key in Settings ▸ SSH, or configure a credential helper, then try again."
        case let .sourceUnavailable(source, reason):
            "Cannot clone \(source).\n\(reason)"
        }
    }
}
