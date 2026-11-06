import MorkDomain
import Foundation
import Observation

@MainActor
@Observable
public final class ApplyPatchViewModel: Identifiable {
    public enum Check: Equatable, Sendable {
        case idle
        case checking
        case passed
        case failed(String)
    }

    public let file: URL
    public private(set) var preview: Loadable<PatchPreview> = .loading
    public private(set) var mode: PatchApplyMode = .workingTree
    public private(set) var check: Check = .idle
    public private(set) var isApplying = false

    @ObservationIgnored private let tools: WorkingCopyToolsDependencies
    @ObservationIgnored private let onApplied: @MainActor (PatchApplyMode) async -> Void

    init(file: URL, tools: WorkingCopyToolsDependencies, onApplied: @escaping @MainActor (PatchApplyMode) async -> Void) {
        self.file = file
        self.tools = tools
        self.onApplied = onApplied
    }

    public nonisolated var id: URL { file }

    public var availableModes: [PatchApplyMode] {
        guard case let .loaded(preview) = preview, preview.isMailbox else { return [.workingTree, .index] }
        return PatchApplyMode.allCases
    }

    public var canApply: Bool { check == .passed && !isApplying }

    func load() async {
        do {
            let loaded = try await tools.loadPatchPreview.execute(file: file)
            preview = .loaded(loaded)
            mode = loaded.isMailbox ? .mailbox : .workingTree
            guard !loaded.files.isEmpty else {
                check = .failed(GitDomainError.emptyPatch.localizedDescription)
                return
            }
            await runCheck()
        } catch {
            preview = .failed(error.localizedDescription)
        }
    }

    public func select(_ mode: PatchApplyMode) async {
        guard availableModes.contains(mode), mode != self.mode, case let .loaded(preview) = preview, !preview.files.isEmpty else { return }
        self.mode = mode
        await runCheck()
    }

    public func apply() async {
        guard canApply else { return }
        isApplying = true
        defer { isApplying = false }
        do {
            try await tools.applyPatch.execute(file: file, mode: mode)
            await onApplied(mode)
        } catch {
            check = .failed(Self.message(of: error))
        }
    }

    private func runCheck() async {
        let mode = mode
        check = .checking
        do {
            try await tools.checkPatch.execute(file: file, mode: mode)
            guard mode == self.mode else { return }
            check = .passed
        } catch {
            guard mode == self.mode else { return }
            check = .failed(Self.message(of: error))
        }
    }

    private static func message(of error: Error) -> String {
        if case let GitDomainError.commandFailed(_, _, message) = error {
            return message.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return error.localizedDescription
    }
}
