import MorkDomain
import Foundation

public enum StageAllDirection: Sendable {
    case stage
    case unstage

    public var title: String {
        switch self {
        case .stage: "Stage All"
        case .unstage: "Unstage All"
        }
    }

    public var systemImage: String {
        switch self {
        case .stage: "chevron.down.2"
        case .unstage: "chevron.up.2"
        }
    }
}

extension RepositoryViewModel {
    public var stageAllDirection: StageAllDirection? {
        if unstagedChanges.contains(where: { !$0.isConflicted }) { return .stage }
        return stagedChanges.isEmpty ? nil : .unstage
    }

    public func toggleStageAll() async {
        switch stageAllDirection {
        case .stage: await stageAll()
        case .unstage: await unstageAll()
        case nil: return
        }
    }
}
