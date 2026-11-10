import MorkDomain
import SwiftUI

struct BranchMenuButton: View {
    let viewModel: RepositoryViewModel
    @State private var anchor = MenuAnchor()

    var body: some View {
        ToolbarSplitButton(title: "Branch", systemImage: "arrow.triangle.branch", identifier: "toolbar.branch", menuIdentifier: "toolbar.branchMenu") {
            viewModel.sheet = .branch
        } menuAction: {
            anchor.popUp(entries)
        }
        .background(MenuAnchorView(anchor: anchor))
        .help("Create a branch; the arrow opens New Worktree and lean branching")
    }

    private var entries: [MenuEntry] {
        var entries = [
            MenuEntry(title: "New Branch…", identifier: "branchButton.newBranch") { viewModel.sheet = .branch },
            MenuEntry(title: "New Worktree…", identifier: "branchButton.newWorktree") { viewModel.sheet = .worktree }
        ]
        guard let base = viewModel.leanBase, let current = viewModel.currentBranch, let target = viewModel.leanSyncTarget else { return entries }
        entries += [
            .separator,
            MenuEntry(title: "Lean Branching", identifier: "branchButton.leanHeader", isEnabled: false) {},
            MenuEntry(title: "Start Branch on '\(base.name)'…", identifier: "branchButton.leanStart") { viewModel.sheet = .startLeanBranch },
            MenuEntry(title: "Sync '\(current.name)' (Rebase on '\(target)')", identifier: "branchButton.leanSync") { Task { await viewModel.syncLeanBranch() } },
            MenuEntry(title: "Finish (Merge into '\(base.name)')…", identifier: "branchButton.leanFinish", isEnabled: viewModel.canFinishLeanBranch) { viewModel.sheet = .finishLeanBranch }
        ]
        return entries
    }
}

struct LeanFinishSheet: View {
    let viewModel: RepositoryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var plan: Result<[GitFlowStep], LeanFinishProblem>?

    var body: some View {
        DialogScaffold(
            kind: .form,
            glyph: "arrow.triangle.merge",
            title: "Finish '\(viewModel.currentBranch?.name ?? "")'"
        ) {
            switch plan {
            case let .success(steps):
                VStack(alignment: .leading, spacing: Metrics.Spacing.s) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                        VStack(alignment: .leading, spacing: Metrics.Spacing.xs) {
                            CommandStrip(command: step.commandLine)
                            DialogNote(text: step.note)
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("leanFinishSheet.steps")
            case let .failure(problem):
                DialogNote(text: problem.message, tone: .warning)
                    .accessibilityIdentifier("leanFinishSheet.problem")
            case nil:
                ProgressView().controlSize(.small)
            }
        } buttons: {
            DialogCancelButton { dismiss() }
            DialogConfirmButton(title: "Finish", identifier: "leanFinishSheet.confirm") {
                guard case let .success(steps) = plan else { return }
                Task { await viewModel.finishLeanBranch(steps) }
                dismiss()
            }
            .disabled(!isReady)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("leanFinishSheet")
        .task { plan = await viewModel.planLeanFinish() }
    }

    private var isReady: Bool {
        if case .success = plan { return true }
        return false
    }
}

struct CreateBranchSheet: View {
    static let detachedStart = "HEAD"

    let viewModel: RepositoryViewModel
    @State private var name = "feature/"
    @AppStorage(BranchAtCommitSheet.checkoutKey) private var checkout = true
    @State private var start: String

    init(viewModel: RepositoryViewModel) {
        self.viewModel = viewModel
        _start = State(initialValue: viewModel.currentBranch?.name ?? Self.detachedStart)
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var problem: BranchNameError? { BranchNameRules.problem(with: trimmed, existing: viewModel.localBranches.map(\.name)) }
    private var startBranch: Branch? { viewModel.localBranches.first { $0.name == start } }

    private var startItems: [BranchPopUp.Item] {
        let detached = viewModel.currentBranch == nil ? [BranchPopUp.Item(title: "HEAD (detached)", tag: Self.detachedStart)] : []
        return detached + viewModel.localBranches.map { BranchPopUp.Item(title: $0.name, tag: $0.name, systemImage: $0.isCurrent ? "checkmark" : "arrow.triangle.branch") }
    }

    var body: some View {
        RemoteDialog(
            title: "New Branch",
            glyph: "arrow.triangle.branch",
            kind: .form,
            confirmTitle: "Create Branch",
            identifier: "branchSheet",
            canConfirm: problem == nil,
            command: command,
            commandIdentifier: "branchSheet.command",
            onConfirm: create
        ) {
            DialogLabeledRow("Name") {
                BranchNameCompletionInput(name: $name, branchNames: viewModel.localBranches.map(\.name), identifier: "branchSheet") {
                    if problem == nil { create() }
                }
            }
            if let problem, trimmed != "feature/" {
                DialogLabeledRow(nil) {
                    DialogNote(text: problem.localizedDescription, tone: .danger)
                        .accessibilityIdentifier("branchSheet.error")
                }
            }
            DialogLabeledRow("Start at") {
                BranchPopUp(items: startItems, selection: $start, identifier: "branchSheet.base")
            }
            DialogLabeledRow(nil) {
                DialogOptionToggle(title: "Check out after creating", isOn: $checkout)
                    .disabled(startBranch == nil)
                    .accessibilityIdentifier("branchSheet.checkout")
            }
        }
    }

    private var command: String {
        let branchName = trimmed.isEmpty ? "<name>" : trimmed
        guard startBranch != nil else { return DialogCommands.line(["switch", "-c", branchName]) }
        return DialogCommands.createBranch(name: branchName, startPoint: start, checkout: checkout)
    }

    private func create() {
        let branchName = trimmed
        let checkout = checkout
        if let startBranch {
            Task { await viewModel.createBranch(named: branchName, from: startBranch, checkout: checkout) }
        } else {
            Task { await viewModel.createBranch(named: branchName) }
        }
    }
}
