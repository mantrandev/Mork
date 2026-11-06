import Foundation

public enum LFSInstallation: Equatable, Sendable {
    case notInstalled
    case installed(version: String)

    public static let installCommand = "brew install git-lfs"

    public var isInstalled: Bool {
        if case .installed = self { return true }
        return false
    }
}

public struct LFSPointer: Equatable, Sendable {
    public static let versionPrefix = "version https://git-lfs.github.com/spec/"

    public let oid: String
    public let size: Int64

    public init(oid: String, size: Int64) {
        self.oid = oid
        self.size = size
    }

    public init?(text: String) {
        let lines = text.split(whereSeparator: \.isNewline)
        guard lines.first?.hasPrefix(Self.versionPrefix) == true else { return nil }
        var oid: String?
        var size: Int64?
        for line in lines.dropFirst() {
            if line.hasPrefix("oid ") {
                oid = String(line.dropFirst(4))
            } else if line.hasPrefix("size ") {
                size = Int64(line.dropFirst(5))
            }
        }
        guard let oid, !oid.isEmpty, let size, size >= 0 else { return nil }
        self.init(oid: oid, size: size)
    }
}

public struct LFSPointerChange: Equatable, Sendable {
    public let old: LFSPointer?
    public let new: LFSPointer?

    public init(old: LFSPointer?, new: LFSPointer?) {
        self.old = old
        self.new = new
    }

    public static func parse(diff: String) -> LFSPointerChange? {
        var oldLines: [Substring] = []
        var newLines: [Substring] = []
        var inHunk = false
        for line in diff.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("diff --git ") {
                if inHunk { return nil }
                continue
            }
            if line.hasPrefix("@@") {
                inHunk = true
                continue
            }
            guard inHunk, let marker = line.first else { continue }
            let content = line.dropFirst()
            switch marker {
            case " ":
                oldLines.append(content)
                newLines.append(content)
            case "-":
                oldLines.append(content)
            case "+":
                newLines.append(content)
            default:
                continue
            }
        }
        guard inHunk else { return nil }
        let oldText = oldLines.joined(separator: "\n")
        let newText = newLines.joined(separator: "\n")
        let old = LFSPointer(text: oldText)
        let new = LFSPointer(text: newText)
        guard old != nil || new != nil, oldText.isEmpty || old != nil, newText.isEmpty || new != nil else { return nil }
        return LFSPointerChange(old: old, new: new)
    }

    public var summary: String {
        switch (old, new) {
        case let (nil, new?): "LFS object (\(Self.size(new.size)))"
        case let (old?, nil): "LFS object removed (\(Self.size(old.size)))"
        case let (old?, new?) where old.size == new.size: "LFS object (\(Self.size(new.size))), new content"
        case let (old?, new?): "LFS object \(Self.size(old.size)) → \(Self.size(new.size))"
        case (nil, nil): "LFS object"
        }
    }

    public static func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

public enum LFSError: LocalizedError, Equatable, Sendable {
    case notInstalled
    case emptyPattern

    public var errorDescription: String? {
        switch self {
        case .notInstalled: "Git LFS is not installed. Install it with \(LFSInstallation.installCommand), then try again."
        case .emptyPattern: "Enter a pattern such as *.psd or assets/**."
        }
    }
}
