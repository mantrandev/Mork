import Foundation

public struct RevertOptions: Hashable, Sendable {
    public static let standard = RevertOptions()

    public let commitsResult: Bool

    public init(commitsResult: Bool = true) {
        self.commitsResult = commitsResult
    }

    public func arguments(revision: String, mainline: Int?) -> [String] {
        arguments(revisions: [revision], mainline: mainline)
    }

    public func arguments(revisions: [String], mainline: Int?) -> [String] {
        ["revert", commitsResult ? "--no-edit" : "--no-commit"]
            + (mainline.map { ["-m", "\($0)"] } ?? [])
            + revisions
    }

    public func arguments(reverting newestFirst: [Commit], abbreviated: Bool = false) -> [String] {
        arguments(revisions: newestFirst.map { abbreviated ? $0.shortHash : $0.hash }, mainline: newestFirst.mainline)
    }
}
