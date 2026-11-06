import MorkDomain
import Foundation

public enum BisectBadgeKind: String, Sendable {
    case good
    case bad
    case skip
    case candidate
    case firstBad
}

public struct BisectLogText: Identifiable, Equatable, Sendable {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public var id: String { text }
}

extension RepositoryViewModel {
    public var isBisecting: Bool { bisectSession != nil }
    public var bisectResult: BisectCommit? { bisectSession?.firstBad }

    public var canMarkBisect: Bool {
        guard let session = bisectSession else { return false }
        return session.firstBad == nil
    }

    public var canSkipBisect: Bool {
        switch bisectSession?.state {
        case .testing, .onlySkipped: true
        case .waiting, .found, nil: false
        }
    }

    public var bisectSummary: String {
        switch bisectSession?.state {
        case .waiting(.goodAndBad): "Bisecting: waiting for a bad and a good commit"
        case .waiting(.good): "Bisecting: bad commit known, waiting for a good commit"
        case .waiting(.bad): "Bisecting: good commit known, waiting for a bad commit"
        case let .testing(progress, _): progress?.summary ?? "Bisecting: test the checked-out commit"
        case let .found(commit): "\(commit.shortHash) is the first bad commit"
        case .onlySkipped: "Only skipped commits are left to test"
        case nil: ""
        }
    }

    public var bisectHint: String? {
        switch bisectSession?.state {
        case .waiting(.goodAndBad):
            "Right-click a commit where the bug happens ▸ Bisect: Mark as Bad, then an older commit without it ▸ Bisect: Mark as Good. Git then checks out the commit halfway between."
        case .waiting(.good):
            "git waits for a good commit: right-click an older commit where the bug does not happen ▸ Bisect: Mark as Good."
        case .waiting(.bad):
            "git waits for a bad commit: right-click a commit where the bug happens ▸ Bisect: Mark as Bad."
        case let .testing(_, candidate):
            "Test the checked-out commit\(candidate.map { " \($0.shortHash) \($0.subject)" } ?? ""), then answer Good, Bad, or Skip if it cannot be tested."
        case let .onlySkipped(commits):
            "The first bad commit could be any of: \(commits.map { "\($0.shortHash) \($0.subject)".trimmingCharacters(in: .whitespaces) }.joined(separator: ", ")). Mark one of them Good or Bad, or Reset."
        case .found, nil:
            nil
        }
    }

    public func bisectBadge(for commit: Commit) -> BisectBadgeKind? {
        guard let session = bisectSession else { return nil }
        if session.firstBad?.hash == commit.hash { return .firstBad }
        if session.candidate?.hash == commit.hash { return .candidate }
        return switch session.marks[commit.hash] {
        case .good: .good
        case .bad: .bad
        case .skip: .skip
        case nil: nil
        }
    }

    public func startBisect() async {
        await perform { _ = try await $0.bisect.startBisect.execute() }
    }

    public func markBisect(_ mark: BisectMark, commit: Commit? = nil) async {
        var outcome: BisectState?
        await perform { outcome = try await $0.bisect.markBisectCommit.execute(mark: mark, commit: commit) }
        if case let .found(culprit) = outcome { await showBisectResult(culprit) }
    }

    public func showBisectResult(_ culprit: BisectCommit) async {
        pane = .history
        clearSearch()
        if let commit = historyRows.first(where: { $0.commit.hash == culprit.hash })?.commit {
            reveal(commit)
            return
        }
        do {
            let loadCommit = dependencies.exploration.loadCommit
            reveal(try await reading { try await loadCommit.execute(revision: culprit.hash) })
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func resetBisect() async {
        var result = BisectResetResult.notBisecting
        await perform { result = try await $0.bisect.resetBisect.execute() }
        guard case let .originalHeadMissing(name) = result else { return }
        notice = Notice(
            title: "Bisect Ended",
            message: "The branch \(name) you started from no longer exists, so git bisect reset HEAD ended the bisect and stayed on the current commit (detached HEAD). Create a branch here or switch to another branch."
        )
    }

    public func showBisectLog() async {
        do {
            let loadBisectLog = dependencies.bisect.loadBisectLog
            bisectLog = BisectLogText(text: try await reading { try await loadBisectLog.execute() })
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
