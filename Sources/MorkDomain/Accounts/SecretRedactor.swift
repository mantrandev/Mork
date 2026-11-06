import Foundation

public enum SecretRedactor {
    public static let mask = "***"
    public static let largeOutputLimit = 1 << 20
    private static let tokenPrefixes = ["ghp_", "gho_", "ghu_", "ghs_", "ghr_", "github_pat_", "glpat-"]

    private static let userInfo = try! NSRegularExpression(pattern: #"([A-Za-z][A-Za-z0-9+.\-]*://[^/@\s:'"]+):[^@/\s'"]+@"#)
    private static let tokens = try! NSRegularExpression(pattern: #"(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_\-]{20,})"#)

    public static func redact(_ text: String) -> String {
        var result = text
        if result.contains("://"), result.contains("@") {
            result = replace(userInfo, in: result, with: "$1:\(mask)@")
        }
        if tokenPrefixes.contains(where: result.contains) {
            result = replace(tokens, in: result, with: mask)
        }
        return result
    }

    private static func replace(_ expression: NSRegularExpression, in text: String, with template: String) -> String {
        expression.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: template)
    }
}

extension GitCommandRecord {
    public func redacted() -> GitCommandRecord {
        GitCommandRecord(
            id: id,
            arguments: arguments.map(SecretRedactor.redact),
            kind: kind,
            exitCode: exitCode,
            stdout: stdout.utf8.count > SecretRedactor.largeOutputLimit ? stdout : SecretRedactor.redact(stdout),
            stderr: SecretRedactor.redact(stderr),
            startedAt: startedAt,
            duration: duration,
            notes: notes.map(SecretRedactor.redact),
            program: program
        )
    }
}
