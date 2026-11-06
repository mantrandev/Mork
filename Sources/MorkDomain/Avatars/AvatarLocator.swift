import Foundation

public enum AvatarLocator {
    public static let pixelSize = 64

    static let gitHub = "https://avatars.githubusercontent.com"
    static let gravatar = "https://en.gravatar.com/avatar"
    static let webFlowEmail = "noreply@github.com"
    static let webFlowUserID = "9919"
    static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    public static func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public static func candidates(for email: String, md5: (String) -> String) -> [URL] {
        let email = normalizedEmail(email)
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count >= 2, parts.allSatisfy({ !$0.isEmpty }) else { return [] }
        if email == webFlowEmail {
            return urls(["\(gitHub)/u/\(webFlowUserID)?s=\(pixelSize)"])
        }
        if let match = email.wholeMatch(of: #/(?:(\d+)\+)?(.+?)@users\.noreply\.github\.com/#) {
            if let id = match.1 {
                return urls(["\(gitHub)/u/\(id)?s=\(pixelSize)"])
            }
            return urls(["\(gitHub)/\(encoded(String(match.2)))?s=\(pixelSize)"])
        }
        return urls([
            "\(gitHub)/u/e?email=\(encoded(email))&s=\(pixelSize)",
            "\(gravatar)/\(md5(email))?d=404&s=\(pixelSize)"
        ])
    }

    private static func encoded(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }

    private static func urls(_ strings: [String]) -> [URL] {
        strings.compactMap(URL.init(string:))
    }
}
