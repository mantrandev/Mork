import MorkDomain
import Foundation
import Observation

public struct MeldMarker: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let start = MeldMarker(rawValue: 1)
    public static let through = MeldMarker(rawValue: 2)
    public static let end = MeldMarker(rawValue: 4)
}

public struct RewordMessage: Equatable, Sendable {
    public let shortHash: String
    public let message: String

    public init(shortHash: String, message: String) {
        self.shortHash = shortHash
        self.message = message
    }
}

public struct RebaseMessageDraft: Identifiable, Equatable, Sendable {
    public let stepID: RebaseStep.ID
    public let shortHash: String
    public let previousAction: RebaseAction
    public var subject: String
    public var description: String

    init(step: RebaseStep) {
        let lines = step.message.split(maxSplits: 1, omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        stepID = step.id
        shortHash = step.commit.shortHash
        previousAction = step.action
        subject = lines.first.map(String.init) ?? ""
        description = lines.count > 1 ? String(lines[1]).trimmingCharacters(in: .whitespacesAndNewlines) : ""
    }

    public var id: RebaseStep.ID { stepID }
    public var canSave: Bool { !trimmedSubject.isEmpty }

    var message: String {
        let body = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return body.isEmpty ? trimmedSubject : "\(trimmedSubject)\n\n\(body)"
    }

    private var trimmedSubject: String { subject.trimmingCharacters(in: .whitespacesAndNewlines) }
}

@MainActor
@Observable
public final class InteractiveRebaseViewModel: Identifiable {
    public typealias Run = @MainActor ([RebaseStep], InteractiveRebaseOptions) async -> Void

    public let id = UUID()
    public let base: RebaseBase
    public let branchName: String
    public let skippedMerges: [Commit]
    public let hasUncommittedChanges: Bool
    public private(set) var steps: [RebaseStep] {
        didSet { meldMarkers = Self.meldMarkers(for: steps.reversed()) }
    }
    public private(set) var meldMarkers: [RebaseStep.ID: MeldMarker] = [:]
    public private(set) var isRunning = false
    public private(set) var messageDraft: RebaseMessageDraft?
    public var selectedStepID: RebaseStep.ID?
    public var updatesDependentBranches = false
    public var createsBackup = false

    @ObservationIgnored private let run: Run

    public init(base: RebaseBase, branchName: String, steps: [RebaseStep], skippedMerges: [Commit] = [], hasUncommittedChanges: Bool, run: @escaping Run) {
        self.base = base
        self.branchName = branchName
        self.steps = steps
        self.skippedMerges = skippedMerges
        self.hasUncommittedChanges = hasUncommittedChanges
        self.run = run
        selectedStepID = steps.last?.id
        meldMarkers = Self.meldMarkers(for: steps.reversed())
    }

    public var displayedSteps: [RebaseStep] { steps.reversed() }
    public var selectedStep: RebaseStep? { selectedStepID.flatMap(index(of:)).map { steps[$0] } }

    public var skippedMergesNotice: String? {
        guard !skippedMerges.isEmpty else { return nil }
        let count = skippedMerges.count == 1 ? "1 merge commit is" : "\(skippedMerges.count) merge commits are"
        return "\(count) left out. git rebase -i replays only regular commits, one after another, so the history ends up on one line. Use git rebase -i --rebase-merges in the console to keep the merges."
    }

    public var startTitle: String { hasUncommittedChanges ? "Stash and Rebase" : "Rebase" }

    public var command: String {
        (["git"] + RebaseCommand.interactive(onto: base, autostash: hasUncommittedChanges, updateRefs: updatesDependentBranches)).map(ShellWords.quote).joined(separator: " ")
    }

    public var preview: String { (try? RebaseTodoBuilder.build(steps))?.text ?? "" }
    public var canStart: Bool { !isRunning && validationMessage == nil }

    public var validationMessage: String? {
        do {
            _ = try RebaseTodoBuilder.build(steps)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    public var rewordMessages: [RewordMessage] {
        steps.filter { $0.action == .reword }.map { RewordMessage(shortHash: $0.commit.shortHash, message: $0.message) }
    }

    public func setAction(_ action: RebaseAction, for id: RebaseStep.ID) {
        guard let index = index(of: id) else { return }
        if action == .reword {
            messageDraft = RebaseMessageDraft(step: steps[index])
        }
        steps[index].action = action
    }

    public func saveMessage(_ draft: RebaseMessageDraft) {
        guard draft.canSave, let index = index(of: draft.stepID) else { return }
        if draft != messageDraft {
            steps[index].message = draft.message
        }
        messageDraft = nil
    }

    public func cancelMessageEdit() {
        guard let draft = messageDraft, let index = index(of: draft.stepID) else { return }
        steps[index].action = draft.previousAction
        messageDraft = nil
    }

    public func moveDisplayed(fromOffsets source: IndexSet, toOffset destination: Int) {
        var displayed = displayedSteps
        displayed.move(fromOffsets: source, toOffset: destination)
        steps = displayed.reversed()
    }

    public enum Direction: Sendable {
        case up
        case down
    }

    public func canMoveSelected(_ direction: Direction) -> Bool {
        guard let target = displayedTarget(direction) else { return false }
        return displayedSteps.indices.contains(target)
    }

    public func moveSelected(_ direction: Direction) {
        guard let id = selectedStepID, let target = displayedTarget(direction), displayedSteps.indices.contains(target),
              let current = displayedSteps.firstIndex(where: { $0.id == id }) else { return }
        var displayed = displayedSteps
        displayed.swapAt(current, target)
        steps = displayed.reversed()
    }

    @discardableResult
    public func applyShortcut(_ key: Character) -> Bool {
        guard messageDraft == nil, let id = selectedStepID, let action = RebaseAction(abbreviation: key) else { return false }
        setAction(action, for: id)
        return true
    }

    private static func meldMarkers(for displayed: [RebaseStep]) -> [RebaseStep.ID: MeldMarker] {
        var markers: [RebaseStep.ID: MeldMarker] = [:]
        for (index, step) in displayed.enumerated() where step.action.meldsIntoPrevious {
            guard let target = displayed.indices.dropFirst(index + 1).first(where: { displayed[$0].action != .drop }) else { continue }
            markers[step.id, default: []].insert(.start)
            for crossed in (index + 1)..<target {
                markers[displayed[crossed].id, default: []].insert(.through)
            }
            markers[displayed[target].id, default: []].insert(.end)
        }
        return markers
    }

    private func displayedTarget(_ direction: Direction) -> Int? {
        guard let id = selectedStepID, let current = displayedSteps.firstIndex(where: { $0.id == id }) else { return nil }
        return direction == .up ? current - 1 : current + 1
    }

    public func editMessage(for id: RebaseStep.ID) {
        setAction(.reword, for: id)
    }

    public func start() async {
        guard canStart else { return }
        isRunning = true
        let backup = createsBackup ? RebaseBackup.branchName(for: branchName, at: Date()) : nil
        await run(steps, InteractiveRebaseOptions(autostash: hasUncommittedChanges, updateRefs: updatesDependentBranches, backupBranch: backup))
        isRunning = false
    }

    private func index(of id: RebaseStep.ID) -> Int? {
        steps.firstIndex { $0.id == id }
    }
}
