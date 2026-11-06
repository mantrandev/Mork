import Foundation

public enum GitIdentityRules {
    private static let forbiddenNameCharacters = CharacterSet(charactersIn: "<>").union(.newlines)
    private static let forbiddenEmailCharacters = CharacterSet(charactersIn: "<>").union(.whitespacesAndNewlines)

    public static func validated(name: String, email: String, scope: GitConfigScope) throws -> GitIdentity {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty, scope == .global { throw GitIdentityError.emptyName }
        if name.rangeOfCharacter(from: forbiddenNameCharacters) != nil { throw GitIdentityError.invalidName }
        if email.isEmpty, scope == .global { throw GitIdentityError.emptyEmail }
        if !email.isEmpty, !isEmail(email) { throw GitIdentityError.invalidEmail(email) }
        return GitIdentity(name: name.isEmpty ? nil : name, email: email.isEmpty ? nil : email)
    }

    private static func isEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2 && parts.allSatisfy { !$0.isEmpty } && email.rangeOfCharacter(from: forbiddenEmailCharacters) == nil
    }
}
