import MorkDomain
import Foundation

public typealias CommitFileListRow = FileListRow<CommitFileChange>

enum CommitFileList {
    static func rows(_ files: [CommitFileChange], mode: FileListMode, filter: String) -> [CommitFileListRow] {
        let query = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = query.isEmpty ? files : files.filter { $0.path.localizedCaseInsensitiveContains(query) }
        return FileList.rows(matching, mode: mode, path: \.path)
    }
}
