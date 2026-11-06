import Foundation

public enum DiffFileStatus: Hashable, Sendable {
    case modified
    case added
    case deleted
    case renamed
    case copied

    public var title: String {
        switch self {
        case .modified: "Modified"
        case .added: "New"
        case .deleted: "Deleted"
        case .renamed: "Renamed"
        case .copied: "Copied"
        }
    }
}

public struct DiffFileSummary: Hashable, Sendable {
    public let path: String
    public let oldPath: String?
    public let status: DiffFileStatus
    public let oldMode: String?
    public let newMode: String?
    public let isBinary: Bool
    public let additions: Int
    public let deletions: Int

    public init(
        path: String,
        oldPath: String? = nil,
        status: DiffFileStatus,
        oldMode: String? = nil,
        newMode: String? = nil,
        isBinary: Bool = false,
        additions: Int = 0,
        deletions: Int = 0
    ) {
        self.path = path
        self.oldPath = oldPath
        self.status = status
        self.oldMode = oldMode
        self.newMode = newMode
        self.isBinary = isBinary
        self.additions = additions
        self.deletions = deletions
    }

    public init(_ patch: FilePatch) {
        var additions = 0
        var deletions = 0
        for line in patch.hunks.lazy.flatMap(\.lines) {
            switch line.unicodeScalars.first {
            case "+": additions += 1
            case "-": deletions += 1
            default: break
            }
        }
        self.init(header: patch.header, additions: additions, deletions: deletions)
    }

    public init(header: [String], additions: Int, deletions: Int) {
        var minus: String?
        var plus: String?
        var renameFrom: String?
        var renameTo: String?
        var copy = false
        var oldMode: String?
        var newMode: String?
        var added = false
        var deleted = false
        var binary = false
        for line in header {
            if let value = line.value(after: "--- ") {
                minus = value == "/dev/null" ? nil : DiffPath.strip(value, side: "a")
                if value == "/dev/null" { added = true }
            } else if let value = line.value(after: "+++ ") {
                plus = value == "/dev/null" ? nil : DiffPath.strip(value, side: "b")
                if value == "/dev/null" { deleted = true }
            } else if let value = line.value(after: "rename from ") ?? line.value(after: "copy from ") {
                renameFrom = DiffPath.unquote(value)
                copy = line.hasPrefix("copy")
            } else if let value = line.value(after: "rename to ") ?? line.value(after: "copy to ") {
                renameTo = DiffPath.unquote(value)
            } else if let value = line.value(after: "new file mode ") {
                added = true
                newMode = value
            } else if let value = line.value(after: "deleted file mode ") {
                deleted = true
                oldMode = value
            } else if let value = line.value(after: "old mode ") {
                oldMode = value
            } else if let value = line.value(after: "new mode ") {
                newMode = value
            } else if line.hasPrefix("Binary files ") || line == "GIT binary patch" {
                binary = true
            }
        }
        let fallback = header.first.map(DiffPath.fromGitLine) ?? ""
        let path = renameTo ?? plus ?? minus ?? fallback
        let original = renameFrom ?? (minus != nil && plus != nil && minus != plus ? minus : nil)
        let status: DiffFileStatus = if added { .added } else if deleted { .deleted } else if renameTo != nil { copy ? .copied : .renamed } else { .modified }
        self.init(path: path, oldPath: original, status: status, oldMode: oldMode, newMode: newMode, isBinary: binary, additions: additions, deletions: deletions)
    }

    public var hasModeChange: Bool {
        guard let oldMode, let newMode else { return false }
        return oldMode != newMode
    }
}

public struct PatchPreview: Hashable, Sendable {
    public let isMailbox: Bool
    public let subject: String?
    public let files: [DiffFileSummary]

    public init(isMailbox: Bool, subject: String?, files: [DiffFileSummary]) {
        self.isMailbox = isMailbox
        self.subject = subject
        self.files = files
    }

    public var additions: Int { files.reduce(0) { $0 + $1.additions } }
    public var deletions: Int { files.reduce(0) { $0 + $1.deletions } }

    public static func parse(_ text: String) -> PatchPreview {
        let files = DiffParser.parse(text).map(DiffFileSummary.init)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard let first = lines.first, isMailboxStart(first), !files.isEmpty else {
            return PatchPreview(isMailbox: false, subject: nil, files: files)
        }
        return PatchPreview(isMailbox: true, subject: subject(in: lines), files: files)
    }

    private static func isMailboxStart(_ line: Substring) -> Bool {
        let fields = line.split(separator: " ", maxSplits: 2)
        guard fields.count >= 2, fields[0] == "From" else { return false }
        return [40, 64].contains(fields[1].count) && fields[1].allSatisfy(\.isHexDigit)
    }

    private static func subject(in lines: [Substring]) -> String? {
        guard let start = lines.firstIndex(where: { $0.hasPrefix("Subject: ") }) else { return nil }
        var subject = String(lines[start].dropFirst("Subject: ".count))
        for line in lines[(start + 1)...] {
            guard line.first == " " || line.first == "\t" else { break }
            subject += " " + line.trimmingCharacters(in: .whitespaces)
        }
        if subject.hasPrefix("["), let close = subject.firstIndex(of: "]") {
            subject = String(subject[subject.index(after: close)...]).trimmingCharacters(in: .whitespaces)
        }
        return subject
    }
}

public enum PatchFileName {
    private static let maxSubjectLength = 52

    public static func suggested(for commit: Commit) -> String {
        var sanitized = ""
        var pendingDash = false
        for character in commit.subject {
            if character.isASCII, character.isLetter || character.isNumber || character == "_" || character == "." {
                if pendingDash, !sanitized.isEmpty { sanitized.append("-") }
                sanitized.append(character)
                pendingDash = false
            } else {
                pendingDash = true
            }
        }
        let trimmed = String(sanitized.prefix(maxSubjectLength)).trimmingCharacters(in: CharacterSet(charactersIn: "-."))
        return "0001-\(trimmed.isEmpty ? commit.shortHash : trimmed).patch"
    }
}

enum DiffPath {
    static func strip(_ value: String, side: Character) -> String {
        var path = unquote(value.hasSuffix("\t") ? String(value.dropLast()) : value)
        if path.hasPrefix("\(side)/") { path.removeFirst(2) }
        return path
    }

    static func fromGitLine(_ line: String) -> String {
        for prefix in ["diff --cc ", "diff --combined "] where line.hasPrefix(prefix) {
            return unquote(String(line.dropFirst(prefix.count)))
        }
        let rest = line.hasPrefix("diff --git ") ? String(line.dropFirst("diff --git ".count)) : line
        if rest.hasPrefix("\""), let end = rest.dropFirst().firstIndex(of: "\""), rest[end...].hasPrefix("\" ") {
            return strip(String(rest[rest.index(after: end)...].dropFirst()), side: "b")
        }
        let half = (rest.count - 1) / 2
        if rest.count % 2 == 1, rest.hasPrefix("a/") {
            let candidate = rest.suffix(half)
            if candidate.hasPrefix("b/") { return String(candidate.dropFirst(2)) }
        }
        return rest
    }

    static func unquote(_ value: String) -> String {
        guard value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") else { return value }
        var bytes: [UInt8] = []
        var scalars = Array(value.unicodeScalars.dropFirst().dropLast())[...]
        while let scalar = scalars.popFirst() {
            guard scalar == "\\", let next = scalars.popFirst() else {
                bytes.append(contentsOf: String(scalar).utf8)
                continue
            }
            switch next {
            case "t": bytes.append(0x09)
            case "n": bytes.append(0x0A)
            case "r": bytes.append(0x0D)
            case "a": bytes.append(0x07)
            case "b": bytes.append(0x08)
            case "f": bytes.append(0x0C)
            case "v": bytes.append(0x0B)
            case "0"..."7":
                var octal = String(next)
                while octal.count < 3, let digit = scalars.first, ("0"..."7").contains(digit) {
                    octal.unicodeScalars.append(digit)
                    scalars.removeFirst()
                }
                bytes.append(UInt8(truncatingIfNeeded: Int(octal, radix: 8) ?? 0))
            default: bytes.append(contentsOf: String(next).utf8)
            }
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}

private extension String {
    func value(after prefix: String) -> String? {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : nil
    }
}
