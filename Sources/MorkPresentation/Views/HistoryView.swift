import AppKit
import MorkDomain
import SwiftUI

struct HistoryView: View {
    static let rowHeight = Metrics.Row.history
    static let maxGraphLanes = 12

    @Bindable var viewModel: RepositoryViewModel
    @Environment(\.isActiveRepositoryTab) private var isActiveTab
    @State private var branchTarget: Commit?
    @State private var tagTarget: Commit?
    @State private var resetTarget: Commit?
    @State private var hardResetTarget: Commit?
    @State private var rebaseSession: InteractiveRebaseViewModel?
    @State private var checkoutTarget: Commit?
    @State private var cherryPickTarget: Commit?
    @State private var revertTarget: Commit?
    @State private var comparison: LocalChangesComparisonViewModel?
    @State private var multiPrompt: MultiCommitPrompt?
    @State private var marks = HistorySelectionMarks()
    @State private var table = HistoryTableLink()

    var body: some View {
        Group {
            if viewModel.historyRows.isEmpty {
                EmptyStateView("No Commits Yet", systemImage: "clock", message: "Stage files, then make the first commit.")
                    .accessibilityIdentifier("history.empty")
            } else {
                GeometryReader { geometry in
                    let columns = HistoryColumns(width: geometry.size.width - Metrics.Spacing.m)
                    let graphWidth = CGFloat(min(viewModel.visibleGraphLanes, Self.maxGraphLanes)) * CommitGraphGeometry.laneSpacing
                    ScrollViewReader { proxy in
                        List(selection: Binding(get: { viewModel.selectedCommit?.hash }, set: { viewModel.selectFromHistoryList($0, extending: NSEvent.modifierFlags.contains(.shift)) })) {
                            HistoryRows(rows: viewModel.visibleHistoryRows, columns: columns, graphWidth: graphWidth, marks: marks, table: table, viewModel: viewModel)
                            if viewModel.isLoadingMoreHistory {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(maxWidth: .infinity)
                                    .accessibilityIdentifier("history.loadingMore")
                            }
                        }
                        .listStyle(.plain)
                        .environment(\.defaultMinListRowHeight, Self.rowHeight)
                        .accessibilityIdentifier("history.list")
                        .contextMenu(forSelectionType: String.self) { hashes in menu(for: hashes) }
                        .overlay { HistorySearchEmptyState(viewModel: viewModel) }
                        .background { HistorySelectionSync(viewModel: viewModel, marks: marks) }
                        .onAppear { table.viewModel = viewModel }
                        .onChange(of: isActiveTab, initial: true) { _, active in table.isInActiveTab = active }
                        .onChange(of: viewModel.scrollRequest, initial: true) { _, request in
                            guard let request, request.hash == viewModel.selectedCommit?.hash else { return }
                            proxy.scrollTo(request.hash, anchor: .center)
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                HistorySearchBar(viewModel: viewModel)
                if !viewModel.historyOptions.filteredBranches.isEmpty {
                    BranchFilterBar(branches: viewModel.historyOptions.filteredBranchNames) {
                        Task { await viewModel.clearHistoryFilter() }
                    }
                }
            }
        }
        .sheet(item: $branchTarget) { commit in
            BranchAtCommitSheet(commit: commit, branchNames: viewModel.localBranches.map(\.name)) { name, checkout in
                Task { await viewModel.createBranch(named: name, at: commit, checkout: checkout) }
            }
        }
        .sheet(item: $tagTarget) { commit in
            CreateTagSheet(viewModel: viewModel, target: .commit(commit), identifier: "tagHereSheet")
        }
        .sheet(item: $rebaseSession) { InteractiveRebaseSheet(session: $0) }
        .sheet(item: $checkoutTarget) { commit in
            CheckoutCommitSheet(commit: commit, branch: viewModel.branchToCheckout(at: commit)) {
                Task { await viewModel.checkout(commit) }
            } checkoutBranch: { branch in
                Task { await viewModel.checkout(branch) }
            }
        }
        .sheet(item: $cherryPickTarget) { commit in
            CherryPickCommitSheet(commit: commit, branchName: branchName) { options in
                Task { await viewModel.cherryPick(commit, options: options) }
            }
        }
        .sheet(item: $revertTarget) { commit in
            RevertCommitSheet(commit: commit) { options in
                Task { await viewModel.revert(commit, options: options) }
            }
        }
        .sheet(item: $comparison, onDismiss: { comparison = nil }) { session in
            LocalChangesComparisonSheet(session: session) {
                session.close()
                comparison = nil
            }
        }
        .morkConfirmation(item: Binding(get: { hardResetTarget.map { ResetPrompt.hard($0) } ?? resetTarget.map { ResetPrompt.choose($0) } }, set: { prompt in
            if prompt == nil {
                resetTarget = nil
                hardResetTarget = nil
            }
        })) { prompt in
            resetConfirmation(prompt)
        }
        .morkConfirmation(item: $multiPrompt) { prompt in
            multiConfirmation(prompt)
        }
    }

    private enum MultiCommitPrompt {
        case cherryPick
        case revert
    }

    private func multiConfirmation(_ prompt: MultiCommitPrompt) -> MorkConfirmation {
        let count = viewModel.selectedCommits.count
        switch prompt {
        case .cherryPick:
            return MorkConfirmation(
                kind: .form,
                glyph: "arrow.uturn.right",
                title: "Cherry-pick \(count) commits onto '\(branchName)'?",
                commands: multiCommand(.cherryPick, identifier: "cherryPickManySheet.command"),
                actions: [DialogAction(title: "Cherry-pick", isDefault: true, identifier: "cherryPickManySheet.confirm") { Task { await viewModel.cherryPickSelectedCommits() } }]
            )
        case .revert:
            return MorkConfirmation(
                kind: .form,
                glyph: "arrow.uturn.backward",
                title: "Revert \(count) commits?",
                commands: multiCommand(.revert, identifier: "revertManySheet.command"),
                actions: [DialogAction(title: "Revert", isDefault: true, identifier: "revertManySheet.confirm") { Task { await viewModel.revertSelectedCommits() } }]
            )
        }
    }

    private func multiCommand(_ action: MultiCommitAction, identifier: String) -> [DialogCommandLine] {
        guard let arguments = viewModel.multiCommitArguments(for: action) else { return [] }
        return [DialogCommandLine(text: DialogCommands.line(arguments), identifier: identifier)]
    }

    private enum ResetPrompt {
        case choose(Commit)
        case hard(Commit)
    }

    private func resetConfirmation(_ prompt: ResetPrompt) -> MorkConfirmation {
        switch prompt {
        case let .choose(commit):
            let confirmsHard = viewModel.confirmsDestructiveActions
            return MorkConfirmation(
                kind: .options,
                glyph: "arrow.uturn.backward",
                title: "Reset \(branchName) to \(commit.shortHash)?",
                actions: [
                    DialogAction(title: "Soft: keep changes staged", command: DialogCommands.reset(.soft, to: commit.hash), identifier: "reset.soft") { Task { await viewModel.reset(to: commit, mode: .soft) } },
                    DialogAction(title: "Mixed: keep changes unstaged", command: DialogCommands.reset(.mixed, to: commit.hash), identifier: "reset.mixed") { Task { await viewModel.reset(to: commit, mode: .mixed) } },
                    DialogAction(title: confirmsHard ? "Hard: discard all changes…" : "Hard: discard all changes", isDestructive: true, command: DialogCommands.reset(.hard, to: commit.hash), identifier: "reset.hard") {
                        if confirmsHard {
                            hardResetTarget = commit
                        } else {
                            Task { await viewModel.reset(to: commit, mode: .hard) }
                        }
                    }
                ]
            )
        case let .hard(commit):
            return MorkConfirmation(
                kind: .destructive,
                title: "Discard all uncommitted changes?",
                message: "Overwrites the index and the working tree. Every uncommitted change is lost and cannot be recovered; untracked files are kept. Commits after \(commit.shortHash) stay in the reflog.",
                commands: [DialogCommandLine(text: DialogCommands.reset(.hard, to: commit.hash))],
                actions: [DialogAction(title: "Reset --hard", isDestructive: true, identifier: "resetHard.confirm") { Task { await viewModel.reset(to: commit, mode: .hard) } }]
            )
        }
    }

    private var branchName: String { viewModel.currentBranch?.name ?? "HEAD" }

    @ViewBuilder
    private func menu(for hashes: Set<String>) -> some View {
        if let hash = hashes.first, viewModel.isMultiCommitSelection, viewModel.selectedCommitHashes.contains(hash) {
            multiMenu(count: viewModel.selectedCommits.count)
        } else if let hash = hashes.first, let commit = viewModel.visibleHistoryCommit(hash) {
            menu(for: commit)
        }
    }

    @ViewBuilder
    private func multiMenu(count: Int) -> some View {
        Button("Cherry-pick \(count) Commits…") { multiPrompt = .cherryPick }
            .accessibilityIdentifier("history.cherryPickMany")
        Button("Revert \(count) Commits…") { multiPrompt = .revert }
            .accessibilityIdentifier("history.revertMany")
        Button("Save Commit Range as Patch…") { Task { await viewModel.saveSelectedRangeAsPatch() } }
            .disabled(viewModel.selectedCommitRange == nil)
            .accessibilityIdentifier("history.saveRangePatch")
        Divider()
        Button("Copy SHAs") { copy(viewModel.selectedCommitSHAs) }
            .keyboardShortcut("c", modifiers: .command)
            .accessibilityIdentifier("history.copySHAs")
        Button("Copy Subjects") { copy(viewModel.selectedCommitSubjects) }
            .accessibilityIdentifier("history.copySubjects")
    }

    @ViewBuilder
    private func menu(for commit: Commit) -> some View {
        Button("New Branch…") { branchTarget = commit }
            .keyboardShortcut("b", modifiers: [.command, .shift])
            .accessibilityIdentifier("history.createBranch")
        Button("New Tag…") { tagTarget = commit }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .accessibilityIdentifier("history.createTag")
        Divider()
        Button("Interactively Rebase '\(branchName)' to Here…") { Task { rebaseSession = await viewModel.makeInteractiveRebase(onto: commit) } }
            .disabled(viewModel.isDetachedHead)
            .accessibilityIdentifier("history.interactiveRebase")
        Divider()
        Button("Reset '\(branchName)' to Here…") { resetTarget = commit }
            .accessibilityIdentifier("history.reset")
        Divider()
        Button("Checkout Commit…") { checkoutTarget = commit }
            .accessibilityIdentifier("history.checkout")
        Button("Cherry-pick Commit…") { cherryPickTarget = commit }
            .accessibilityIdentifier("history.cherryPick")
        Button("Revert Commit…") { revertTarget = commit }
            .accessibilityIdentifier("history.revert")
        Button("Save as Patch…") { Task { await viewModel.createPatch(for: commit) } }
            .accessibilityIdentifier("history.createPatch")
        Divider()
        Button("Compare to Local Changes") { comparison = viewModel.compareToLocalChanges(commit) }
            .accessibilityIdentifier("history.compareToLocal")
        Divider()
        Button("Copy Commit SHA") { copy(commit.hash) }
            .keyboardShortcut("c", modifiers: .command)
            .accessibilityIdentifier("history.copySHA")
        Button("Copy Subject") { copy(commit.subject) }
            .accessibilityIdentifier("history.copySubject")
        Divider()
        Button("Browse Files at This Commit…") { viewModel.browseFiles(at: commit) }
            .accessibilityIdentifier("history.browseFiles")
        Divider()
        BisectMenuItems(viewModel: viewModel, commit: commit)
        CustomCommandsMenu(viewModel: viewModel, location: .commit, commit: commit)
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

struct BranchAtCommitSheet: View {
    static let checkoutKey = "branch.checkoutNew"

    let title: String
    let startPoint: String
    let branchNames: [String]
    let identifier: String
    let onConfirm: (String, Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @AppStorage(BranchAtCommitSheet.checkoutKey) private var checkout = false

    init(title: String, startPoint: String, identifier: String, branchNames: [String], onConfirm: @escaping (String, Bool) -> Void) {
        self.title = title
        self.startPoint = startPoint
        self.branchNames = branchNames
        self.identifier = identifier
        self.onConfirm = onConfirm
    }

    init(commit: Commit, branchNames: [String], onConfirm: @escaping (String, Bool) -> Void) {
        self.init(title: "New Branch at \(commit.shortHash)", startPoint: commit.shortHash, identifier: "branchHereSheet", branchNames: branchNames, onConfirm: onConfirm)
    }

    var body: some View {
        DialogScaffold(
            kind: .form,
            glyph: "arrow.triangle.branch",
            title: title
        ) {
            VStack(alignment: .leading, spacing: Metrics.Sheet.rowSpacing) {
                DialogLabeledRow("Name") {
                    BranchNameCompletionInput(name: $name, branchNames: branchNames, identifier: identifier, onSubmit: confirm)
                }
                DialogLabeledRow(nil) {
                    DialogOptionToggle(title: "Check out the new branch", isOn: $checkout)
                        .accessibilityIdentifier("\(identifier).checkout")
                }
            }
            CommandStrip(command: command, identifier: "\(identifier).command")
        } buttons: {
            DialogCancelButton { dismiss() }
            DialogConfirmButton(title: "Create Branch", identifier: "\(identifier).confirm", action: confirm)
                .disabled(isEmpty)
        }
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var isEmpty: Bool { trimmedName.isEmpty }

    private var command: String {
        DialogCommands.createBranch(name: isEmpty ? "<name>" : trimmedName, startPoint: startPoint, checkout: checkout)
    }

    private func confirm() {
        guard !isEmpty else { return }
        onConfirm(name, checkout)
        dismiss()
    }
}

private struct HistoryRows: View, Equatable {
    let rows: [HistoryRowModel]
    let columns: HistoryColumns
    let graphWidth: CGFloat
    let marks: HistorySelectionMarks
    let table: HistoryTableLink
    let viewModel: RepositoryViewModel

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.rows == rhs.rows && lhs.columns == rhs.columns && lhs.graphWidth == rhs.graphWidth && lhs.marks === rhs.marks && lhs.table === rhs.table && lhs.viewModel === rhs.viewModel
    }

    var body: some View {
        let firstID = rows.first?.id
        ForEach(rows, id: \.id) { row in
            HistoryRow(row: row, columns: columns, graphWidth: graphWidth, isFirst: row.id == firstID, mark: marks.mark(for: row.commit.hash), table: table, viewModel: viewModel)
        }
    }
}

@MainActor @Observable final class HistorySelectionMarks {
    @MainActor @Observable final class Mark {
        var isSelected = false
    }

    @ObservationIgnored private var marks: [String: Mark] = [:]
    @ObservationIgnored private(set) var selectedHashes: Set<String> = []

    func mark(for hash: String) -> Mark {
        if let mark = marks[hash] { return mark }
        let mark = Mark()
        mark.isSelected = selectedHashes.contains(hash)
        marks[hash] = mark
        return mark
    }

    func select(_ hashes: Set<String>) {
        guard hashes != selectedHashes else { return }
        for hash in selectedHashes where !hashes.contains(hash) { marks[hash]?.isSelected = false }
        for hash in hashes where !selectedHashes.contains(hash) { marks[hash]?.isSelected = true }
        selectedHashes = hashes
    }
}

enum HistoryRowBackground {
    static func color(isSelected: Bool) -> Color? {
        isSelected ? Palette.Accent.tint.color : nil
    }
}

private struct HistorySelectionSync: View {
    let viewModel: RepositoryViewModel
    let marks: HistorySelectionMarks

    var body: some View {
        Color.clear
            .onChange(of: viewModel.selectedCommitHashes, initial: true) { _, hashes in marks.select(hashes) }
            .accessibilityHidden(true)
    }
}

private struct HistoryRow: View {
    let row: HistoryRowModel
    let columns: HistoryColumns
    let graphWidth: CGFloat
    let isFirst: Bool
    let mark: HistorySelectionMarks.Mark
    let table: HistoryTableLink
    let viewModel: RepositoryViewModel

    var body: some View {
        let isSelected = mark.isSelected
        CommitRow(model: row, columns: columns, graphWidth: graphWidth, isSelected: isSelected, signatures: viewModel.signatureBadges)
            .frame(height: HistoryView.rowHeight)
            .background { if isSelected || isFirst { HistoryTableHook(link: table) } }
            .listRowBackground(HistoryRowBackground.color(isSelected: isSelected))
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: Metrics.Spacing.xs, bottom: 0, trailing: Metrics.Spacing.s))
            .tag(row.commit.hash)
            .onHover { inside in
                if inside { viewModel.hoverCommit(row.commit) } else { viewModel.endHover(row.commit) }
            }
            .onAppear {
                viewModel.loadMoreHistoryIfNeeded(after: row.id)
                viewModel.requestSignature(for: row.commit.hash)
                viewModel.requestMessage(for: row.commit.hash)
            }
    }
}

private struct CommitRow: View, Equatable {
    let model: HistoryRowModel
    let columns: HistoryColumns
    let graphWidth: CGFloat
    let isSelected: Bool
    let signatures: SignatureBadgeStore

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.model == rhs.model && lhs.columns == rhs.columns && lhs.graphWidth == rhs.graphWidth && lhs.isSelected == rhs.isSelected && lhs.signatures === rhs.signatures
    }

    private var row: GraphRow { model.graph }
    private var commit: Commit { model.commit }
    private var labels: [RefLabel] { model.labels }
    private var bisect: BisectBadgeKind? { model.bisect }
    private var isHead: Bool { model.isHead }
    private var secondary: Color { isSelected ? Palette.Text.primary.color : Palette.Text.secondary.color }

    var body: some View {
        HStack(spacing: HistoryColumns.spacing) {
            HStack(spacing: Metrics.Spacing.xs) {
                CommitGraphView(row: row, isHead: isHead)
                    .frame(width: graphWidth, alignment: .leading)
                    .clipped()
                if commit.syncStatus != .shared {
                    Circle()
                        .fill(commit.syncStatus == .localOnly ? Palette.Status.modified.ink.color : Palette.Text.secondary.color)
                        .frame(width: Metrics.Icon.syncDot, height: Metrics.Icon.syncDot)
                        .help(commit.syncStatus == .localOnly ? "Only on current branch" : "Only on current branch’s upstream")
                        .accessibilityLabel(commit.syncStatus == .localOnly ? "Local only" : "Remote only")
                }
                if commit.isLost {
                    LostCommitBadge()
                }
                if let bisect {
                    BisectBadge(kind: bisect)
                        .fixedSize()
                }
                ForEach(labels, id: \.self) { label in
                    RefBadge(label: label, lane: row.column)
                        .fixedSize()
                }
                SignatureBadge(hash: commit.hash, store: signatures)
                Text(commit.subject)
                    .fontWeight(isHead ? .semibold : .regular)
                    .foregroundStyle(commit.syncStatus == .remoteOnly ? secondary : Palette.Text.primary.color)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, labels.isEmpty ? 0 : 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            if columns.author > 0 {
                HStack(spacing: Metrics.Spacing.xs) {
                    AuthorAvatarImage(name: commit.author, email: commit.authorEmail, style: .row)
                    Text(commit.author)
                        .foregroundStyle(secondary)
                        .lineLimit(1)
                }
                .frame(width: columns.author, alignment: .leading)
            }
            Text(commit.shortHash)
                .font(Metrics.Font.monoCaption)
                .foregroundStyle(secondary)
                .lineLimit(1)
                .frame(width: columns.hash, alignment: .leading)
            Text(model.date)
                .font(Metrics.Font.caption.monospacedDigit())
                .foregroundStyle(secondary)
                .lineLimit(1)
                .frame(width: columns.date, alignment: .trailing)
        }
        .font(Metrics.Font.body)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("commit.\(commit.subject)")
        .accessibilityValue("lane \(row.column)")
    }
}
