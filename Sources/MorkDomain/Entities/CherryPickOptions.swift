import Foundation

public struct CherryPickOptions: Hashable, Sendable {
    public static let standard = CherryPickOptions()

    public let commitsResult: Bool
    public let recordsOrigin: Bool

    public init(commitsResult: Bool = true, recordsOrigin: Bool = false) {
        self.commitsResult = commitsResult
        self.recordsOrigin = commitsResult && recordsOrigin
    }

    public func arguments(revision: String, mainline: Int?) -> [String] {
        arguments(revisions: [revision], mainline: mainline)
    }

    public func arguments(revisions: [String], mainline: Int?) -> [String] {
        ["cherry-pick"]
            + (recordsOrigin ? ["-x"] : [])
            + (commitsResult ? [] : ["--no-commit"])
            + (mainline.map { ["-m", "\($0)"] } ?? [])
            + revisions
    }

    public func arguments(picking newestFirst: [Commit], abbreviated: Bool = false) -> [String] {
        arguments(revisions: newestFirst.reversed().map { abbreviated ? $0.shortHash : $0.hash }, mainline: newestFirst.mainline)
    }
}
