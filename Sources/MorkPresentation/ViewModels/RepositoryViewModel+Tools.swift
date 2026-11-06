import MorkDomain
import Foundation

public struct IgnoreDraft: Identifiable, Hashable, Sendable {
    public let path: String
    public var rule: String
    public var target: IgnoreTarget

    public init(path: String, rule: String, target: IgnoreTarget) {
        self.path = path
        self.rule = rule
        self.target = target
    }

    public var id: String { path }
}

public struct Notice: Identifiable, Equatable, Sendable {
    public let title: String
    public let message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }

    public var id: String { title + "\n" + message }
}

extension RepositoryViewModel {
    public func ignoreSuggestions(for change: FileChange) -> [IgnoreSuggestion] {
        change.isUntracked ? GitIgnorePattern.suggestions(for: change.path) : []
    }

    public func beginCustomIgnore(_ change: FileChange, target: IgnoreTarget) {
        ignoreDraft = IgnoreDraft(path: change.path, rule: ignoreSuggestions(for: change).first?.pattern ?? "", target: target)
    }

    public func ignore(_ change: FileChange, rule: String, target: IgnoreTarget) async {
        await ignore(path: change.path, rule: rule, target: target)
    }

    public func ignore(path: String, rule: String, target: IgnoreTarget) async {
        var result: IgnoreRuleResult?
        await perform { result = try await $0.tools.addIgnoreRule.execute(rule: rule, target: target, path: path) }
        if let result { notice = Self.notice(for: result, path: path) }
    }

    public func beginApplyPatch() async {
        guard let file = await dependencies.tools.panels.choosePatchFile() else { return }
        let session = ApplyPatchViewModel(file: file, tools: dependencies.tools) { [weak self] mode in
            await self?.finishApplyingPatch(file, mode: mode)
        }
        patchSession = session
        await session.load()
    }

    public func createPatch(for commit: Commit) async {
        guard let destination = await dependencies.tools.panels.chooseDestination(suggestedName: PatchFileName.suggested(for: commit)) else { return }
        if await perform({ try await $0.tools.createPatch.execute(commit: commit, destination: destination) }) {
            notice = Notice(
                title: "Patch Saved",
                message: "git format-patch -1 \(commit.shortHash) --stdout was saved to \(destination.path). Apply it in another repository with git am."
            )
        }
    }

    private func finishApplyingPatch(_ file: URL, mode: PatchApplyMode) async {
        patchSession = nil
        notice = Notice(title: "Patch Applied", message: "\(mode.command) \(file.lastPathComponent) finished. \(mode.explanation)")
        await refresh()
    }

    private static func notice(for result: IgnoreRuleResult, path: String) -> Notice {
        let file = result.target.fileName
        let location = result.match.map { "\($0.source) line \($0.line): \($0.pattern)" }
        guard result.added else {
            return Notice(title: "Rule Already Present", message: "\(result.rule) is already in \(file).")
        }
        guard result.ignoresPath, let location else {
            let reason = location.map { " \($0) brings it back." } ?? ""
            return Notice(title: "Ignore Rule Added", message: "\(result.rule) was added to \(file), but it does not match \(path).\(reason)")
        }
        let sharing = result.target == .gitignore ? "Commit .gitignore to share the rule with everyone." : "The rule stays on this computer and is never committed."
        return Notice(title: "Ignore Rule Added", message: "\(location)\n\(path) is now ignored. \(sharing)")
    }
}
