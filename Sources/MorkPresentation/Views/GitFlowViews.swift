import MorkDomain
import SwiftUI

struct GitFlowMenu: View {
    let repository: RepositoryViewModel?

    var body: some View {
        Menu("Git Flow") {
            Button("Initialize…") { show(.initialize) }
            Divider()
            ForEach(GitFlowBranchKind.allCases) { kind in
                Button("Start \(kind.title)…") { show(.start(kind)) }
            }
            Divider()
            ForEach(GitFlowBranchKind.allCases) { kind in
                Button("Finish \(kind.title)…") { show(.finish(kind)) }
            }
        }
        .disabled(repository == nil)
    }

    private func show(_ mode: GitFlowMode) {
        guard let repository else { return }
        Task { await repository.showGitFlow(mode) }
    }
}

struct GitFlowSheet: View {
    @Bindable var session: GitFlowViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        DialogScaffold(
            kind: .options,
            glyph: "arrow.triangle.branch",
            title: session.mode.title,
            message: session.mode.summary,
            width: Metrics.Sheet.wideWidth,
            titleIdentifier: "gitFlow.title"
        ) {
            content
        } buttons: {
            DialogCancelButton(identifier: "gitFlow.cancel") { dismiss() }
            DialogConfirmButton(title: "Run", identifier: "gitFlow.run") { Task { if await session.confirm() { dismiss() } } }
                .disabled(!session.canRun)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("gitFlow.sheet")
    }

    @ViewBuilder
    private var content: some View {
        switch session.context {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity, minHeight: Metrics.Panel.minimumHeight)
        case let .failed(message):
            EmptyStateView("Could Not Read the Repository", systemImage: "exclamationmark.triangle", message: message)
                .frame(minHeight: Metrics.Panel.minimumHeight)
        case .loaded where session.needsInitialization:
            EmptyStateView("Git Flow Is Not Set Up", systemImage: "arrow.triangle.branch", message: "git config has no gitflow.branch.master and gitflow.branch.develop yet.") {
                Button("Initialize Git Flow…") { session.initializeInstead() }
                    .buttonStyle(.morkSecondary)
                    .accessibilityIdentifier("gitFlow.initializeInstead")
            }
            .frame(minHeight: Metrics.Panel.minimumHeight)
        case .loaded:
            form
            GitFlowPreview(session: session)
        }
    }

    @ViewBuilder
    private var form: some View {
        switch session.mode {
        case .initialize:
            VStack(alignment: .leading, spacing: Metrics.Sheet.rowSpacing) {
                field("Production", text: $session.configuration.mainBranch, identifier: "gitFlow.main")
                field("Develop", text: $session.configuration.developBranch, identifier: "gitFlow.develop")
                field("Features", text: $session.configuration.featurePrefix, identifier: "gitFlow.featurePrefix")
                field("Releases", text: $session.configuration.releasePrefix, identifier: "gitFlow.releasePrefix")
                field("Hotfixes", text: $session.configuration.hotfixPrefix, identifier: "gitFlow.hotfixPrefix")
                field("Tag prefix", text: $session.configuration.versionTagPrefix, identifier: "gitFlow.tagPrefix")
            }
        case let .start(kind):
            DialogLabeledRow("Name") {
                HStack(spacing: Metrics.Spacing.xs) {
                    Text(session.prefix)
                        .font(Metrics.Font.monoBody)
                        .foregroundStyle(Palette.Text.secondary.color)
                    DialogTextField(placeholder: kind.namePlaceholder, text: $session.name, identifier: "gitFlow.name")
                }
            }
        case let .finish(kind):
            if session.finishCandidates.isEmpty {
                DialogNote(text: "No \(kind.rawValue) branches (\(session.prefix)*). Start one first.")
                    .accessibilityIdentifier("gitFlow.noBranches")
            } else {
                DialogLabeledRow("Branch") {
                    Picker("Branch", selection: $session.finishBranch) {
                        ForEach(session.finishCandidates, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .accessibilityIdentifier("gitFlow.branch")
                }
            }
        }
    }

    private func field(_ title: String, text: Binding<String>, identifier: String) -> some View {
        DialogLabeledRow(title) {
            DialogTextField(placeholder: title, text: text, identifier: identifier, isMonospaced: true)
        }
    }
}

private struct GitFlowPreview: View {
    let session: GitFlowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.s) {
            Text("Mork will run these git commands, in this order:")
                .font(Metrics.Font.body.weight(.semibold))
                .foregroundStyle(Palette.Text.primary.color)
            if let problem = session.problem {
                DialogNote(text: problem.localizedDescription, tone: .warning)
                    .accessibilityIdentifier("gitFlow.problem")
            }
            List(Array(session.steps.enumerated()), id: \.offset) { index, step in
                VStack(alignment: .leading, spacing: Metrics.Spacing.xxs) {
                    Text("\(index + 1). \(step.commandLine)")
                        .font(Metrics.Font.monoBody)
                        .foregroundStyle(Palette.Text.primary.color)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    Text(step.note)
                        .font(Metrics.Font.caption)
                        .foregroundStyle(Palette.Text.secondary.color)
                        .lineLimit(1)
                        .help(step.note)
                }
                .frame(height: Metrics.Row.twoLine, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("gitFlow.step.\(index)")
                .listRowBackground(Palette.Surface.well.color)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Palette.Surface.well.color)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous))
            .frame(height: Metrics.Panel.minimumHeight + Metrics.Spacing.xxl * 2)
            .accessibilityIdentifier("gitFlow.preview")
            DialogNote(text: "A merge that stops on a conflict leaves the repository in the normal merge state; Mork stops there and lists the steps that are left.")
        }
    }
}
