import MorkDomain
import Foundation

extension GitOutputParser {
    static func treemapFiles(_ output: String) -> [TreemapFile] {
        var files: [TreemapFile] = []
        for record in output.split(separator: "\0") {
            guard let tab = record.firstIndex(of: "\t") else { continue }
            let meta = record[..<tab].split(separator: " ", omittingEmptySubsequences: true)
            guard meta.count == 4, meta[1] == "blob", let size = Int64(meta[3]) else { continue }
            files.append(TreemapFile(path: String(record[record.index(after: tab)...]), size: size))
        }
        return files
    }
}
