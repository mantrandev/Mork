import Foundation

public enum GPGKeyListParser {
    public static func secretSigningKeys(_ output: String) -> [SigningKey] {
        var keys: [SigningKey] = []
        var current: (id: String, length: String, usable: Bool, fingerprint: String?, user: String?)?
        func flush() {
            guard let key = current, key.usable else { return }
            let value = key.fingerprint ?? key.id
            keys.append(SigningKey(
                format: .openpgp,
                value: value,
                title: key.user ?? key.id,
                detail: "\(key.length)-bit key \(String(key.id.suffix(16)))"
            ))
        }
        for line in output.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
            guard let type = fields.first else { continue }
            switch type {
            case "sec":
                flush()
                let validity = fields.count > 1 ? fields[1] : ""
                let capabilities = fields.count > 11 ? fields[11] : ""
                current = (
                    id: fields.count > 4 ? fields[4] : "",
                    length: fields.count > 2 ? fields[2] : "",
                    usable: !["r", "e", "d", "i"].contains(validity) && capabilities.contains("S"),
                    fingerprint: nil,
                    user: nil
                )
            case "fpr":
                if current?.fingerprint == nil, fields.count > 9 { current?.fingerprint = fields[9] }
            case "uid":
                if current?.user == nil, fields.count > 9, !["r", "e"].contains(fields[1]) { current?.user = fields[9] }
            default:
                continue
            }
        }
        flush()
        return keys
    }
}

public enum SSHPublicKeyParser {
    public static func key(path: String, contents: String) -> SigningKey? {
        let line = contents.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let parts = line.split(separator: " ", maxSplits: 2).map(String.init)
        guard parts.count >= 2, parts[0].hasPrefix("ssh-") || parts[0].hasPrefix("ecdsa-") || parts[0].hasPrefix("sk-") else { return nil }
        let name = (path as NSString).lastPathComponent
        let comment = parts.count > 2 ? parts[2].trimmingCharacters(in: .whitespaces) : ""
        return SigningKey(format: .ssh, value: path, title: name, detail: comment.isEmpty ? parts[0] : "\(parts[0]) · \(comment)")
    }
}
