import MorkDomain
import Foundation

enum GitOutputParser {
    static let separator: Character = "\u{1f}"
    static let recordSeparator: Character = "\u{1e}"

    static let historyFormat = "%H%x1f%P%x1f%an%x1f%ae%x1f%at%x1f%D%x1f%s"
    static let branchFormat = "%(HEAD)%1f%(refname:short)%1f%(upstream:short)%1f%(upstream:track)%1f%(refname)%1f%(objectname)"
    static let stashFormat = "%gd%x1f%s"
    static let stashHistoryFormat = "%H%x1f%P%x1f%an%x1f%ae%x1f%at%x1f%gd%x1f%s"
    static let tagFormat = "%(refname:lstrip=2)%1f%(objecttype)%1f%(creatordate:unix)"

    static func status(_ output: String) -> [FileChange] {
        var tokens = output.split(separator: "\0", omittingEmptySubsequences: true)[...]
        var changes: [FileChange] = []
        while let token = tokens.popFirst() {
            let scalars = Array(token.unicodeScalars)
            guard scalars.count > 3 else { continue }
            let index = Character(scalars[0])
            let worktree = Character(scalars[1])
            let original = (index == "R" || index == "C") ? tokens.popFirst().map(String.init) : nil
            let path = String(String.UnicodeScalarView(scalars[3...]))
            changes.append(FileChange(path: path, originalPath: original, index: index, worktree: worktree))
        }
        return changes
    }

    static func commits(_ output: String) -> [Commit] {
        output.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: separator, maxSplits: 6, omittingEmptySubsequences: false).map(String.init)
            guard fields.count == 7, !fields[0].isEmpty else { return nil }
            return Commit(
                hash: fields[0],
                parents: fields[1].split(separator: " ").map(String.init),
                author: fields[2],
                authorEmail: fields[3],
                date: Date(timeIntervalSince1970: TimeInterval(fields[4]) ?? 0),
                refs: fields[5],
                subject: fields[6]
            )
        }
    }

    static func branches(_ output: String) -> [Branch] {
        output.split(separator: "\n").compactMap { line in
            let fields = fields(of: line)
            guard fields.count == 6, !(fields[4].hasPrefix("refs/remotes/") && fields[4].hasSuffix("/HEAD")) else { return nil }
            return Branch(
                name: fields[1],
                fullName: fields[4],
                isCurrent: fields[0] == "*",
                upstream: fields[2].isEmpty ? nil : fields[2],
                track: fields[3],
                hash: fields[5]
            )
        }
    }

    static func stashes(_ output: String) -> [Stash] {
        output.split(separator: "\n").compactMap { line in
            let fields = fields(of: line)
            guard fields.count >= 2, !fields[0].isEmpty else { return nil }
            return Stash(reference: fields[0], message: fields[1...].joined(separator: String(separator)))
        }
    }

    static func tags(_ output: String) -> [Tag] {
        output.split(separator: "\n").compactMap { line in
            let fields = fields(of: line)
            guard (fields.count == 2 || fields.count == 3), !fields[0].isEmpty else { return nil }
            let timestamp = fields.count == 3 ? TimeInterval(fields[2]) : nil
            let createdAt = timestamp.flatMap { $0.isFinite ? Date(timeIntervalSince1970: $0) : nil }
            return Tag(name: fields[0], isAnnotated: fields[1] == "tag", createdAt: createdAt)
        }
    }

    static func nameStatus(_ output: String) -> [CommitFileChange] {
        var tokens = output.split(separator: "\0", omittingEmptySubsequences: true)[...]
        var files: [CommitFileChange] = []
        while let status = tokens.popFirst(), let letter = status.first {
            let isPair = letter == "R" || letter == "C"
            let original = isPair ? tokens.popFirst().map(String.init) : nil
            guard let path = tokens.popFirst(), !isPair || original != nil else { break }
            files.append(CommitFileChange(status: letter, path: String(path), originalPath: original))
        }
        return files
    }

    static func fileHistory(_ output: String) -> [FileHistoryEntry] {
        output.split(separator: recordSeparator).compactMap { record in
            let parts = record.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2,
                  let commit = commits(String(parts[0])).first,
                  let file = nameStatus(String(parts[1])).first
            else { return nil }
            return FileHistoryEntry(commit: commit, file: file)
        }
    }

    static func lines(_ output: String) -> [String] {
        output.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.isEmpty }
    }

    private static func fields(of line: Substring) -> [String] {
        line.split(separator: separator, omittingEmptySubsequences: false).map(String.init)
    }
}
