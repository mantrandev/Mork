import Foundation

public enum ImageFileType {
    public static let extensions: Set<String> = ["png", "jpg", "jpeg", "gif", "heic", "heif", "webp", "tif", "tiff", "bmp", "ico", "pdf"]

    public static func isImage(_ path: String) -> Bool {
        guard let dot = path.lastIndex(of: "."), !path[dot...].contains("/") else { return false }
        return extensions.contains(path[path.index(after: dot)...].lowercased())
    }
}

public struct ImageDiffSources: Hashable, Sendable {
    public let path: String
    public let old: BlobReference?
    public let new: BlobReference?

    public init(path: String, old: BlobReference?, new: BlobReference?) {
        self.path = path
        self.old = old
        self.new = new
    }

    public static func commitFile(_ commit: Commit, _ file: CommitFileChange) -> ImageDiffSources {
        let old = file.status == "A" ? nil : commit.parents.first.map { BlobReference.commit($0, file.originalPath ?? file.path) }
        let new = file.status == "D" ? nil : BlobReference.commit(commit.hash, file.path)
        return ImageDiffSources(path: file.path, old: old, new: new)
    }

    public static func change(_ change: FileChange, staged: Bool) -> ImageDiffSources {
        if staged {
            let old = change.index == "A" ? nil : BlobReference.commit("HEAD", change.originalPath ?? change.path)
            let new = change.index == "D" ? nil : BlobReference(revision: .index, path: change.path)
            return ImageDiffSources(path: change.path, old: old, new: new)
        }
        let old = change.isUntracked ? nil : BlobReference(revision: .index, path: change.path)
        let new = change.worktree == "D" ? nil : BlobReference(revision: .workingTree, path: change.path)
        return ImageDiffSources(path: change.path, old: old, new: new)
    }
}

public enum ImageBlob: Equatable, Sendable {
    public static let limit = 32 * 1024 * 1024

    case missing
    case tooLarge(byteCount: Int)
    case loaded(Data)
}

public struct ImageDiff: Equatable, Sendable {
    public let old: ImageBlob
    public let new: ImageBlob

    public init(old: ImageBlob, new: ImageBlob) {
        self.old = old
        self.new = new
    }
}
