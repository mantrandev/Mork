import Foundation

extension Lessons {
    static let conflictStages: [String: String] = [
        ":1:": "stage 1, the base: the file as it was in the common ancestor both sides started from",
        ":2:": "stage 2, ours: the file as it is on HEAD, the branch you are on (during a rebase, the branch you rebase onto)",
        ":3:": "stage 3, theirs: the incoming version of the file (the merged branch, the picked commit, or your commit being replayed in a rebase)"
    ]

    static func conflictStageNotes(_ arguments: [String], subcommand: String) -> [String] {
        guard subcommand == "show", let start = arguments.firstIndex(of: subcommand) else { return [] }
        let stages = Set(arguments[(start + 1)...].compactMap { argument in
            conflictStages.keys.first { argument.hasPrefix($0) }
        })
        return stages.sorted().compactMap { stage in conflictStages[stage].map { "\(stage) \($0)" } }
    }
}
