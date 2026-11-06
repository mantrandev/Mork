import MorkDomain
import SwiftUI

struct ApplyPatchSheet: View {
    let session: ApplyPatchViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        DialogScaffold(
            kind: .options,
            glyph: "doc.badge.plus",
            title: "Apply Patch",
            message: session.file.path
        ) {
            preview
            DialogLabeledRow("Apply with") {
                VStack(alignment: .leading, spacing: Metrics.Spacing.xs) {
                    Picker("Apply with", selection: Binding(get: { session.mode }, set: { mode in Task { await session.select(mode) } })) {
                        ForEach(session.availableModes) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                    .font(Metrics.Font.title)
                    .accessibilityIdentifier("applyPatch.mode")
                    DialogNote(text: session.mode.explanation)
                }
            }
            checkStatus
            CommandStrip(command: session.mode.command + " " + ShellWords.quote(session.file.path))
        } buttons: {
            DialogCancelButton(identifier: "applyPatch.cancel") { dismiss() }
            DialogConfirmButton(title: "Apply", identifier: "applyPatch.apply") { Task { await session.apply() } }
                .disabled(!session.canApply)
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch session.preview {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity)
        case let .failed(message):
            DialogNote(text: message, tone: .danger)
        case let .loaded(preview):
            VStack(alignment: .leading, spacing: Metrics.Spacing.s) {
                if let subject = preview.subject {
                    Label("Commit: \(subject)", systemImage: "envelope")
                        .font(Metrics.Font.body)
                        .foregroundStyle(Palette.Text.primary.color)
                        .accessibilityIdentifier("applyPatch.subject")
                }
                List(preview.files, id: \.self) { file in
                    HStack(spacing: Metrics.ChangeRow.gap) {
                        FileIcon(path: file.path)
                        FilePathText(path: file.path, originalPath: file.oldPath)
                            .font(Metrics.Font.body)
                        Text(file.status.title)
                            .font(Metrics.Font.caption)
                            .foregroundStyle(Palette.Text.secondary.color)
                        Spacer()
                        Text("+\(file.additions)").foregroundStyle(Palette.Status.added.ink.color)
                        Text("−\(file.deletions)").foregroundStyle(Palette.Status.deleted.ink.color)
                    }
                    .font(Metrics.Font.monoCaption)
                    .frame(height: Metrics.Row.list)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("applyPatch.file.\(file.path)")
                    .listRowInsets(Metrics.listRowInsets)
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, Metrics.Row.list)
                .frame(height: min(CGFloat(preview.files.count) * Metrics.Row.list + Metrics.Spacing.s, Metrics.Sheet.patchFilesHeight))
                .background(Palette.Surface.well.color, in: RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous))
                Text("\(preview.files.count) file(s), +\(preview.additions) −\(preview.deletions)")
                    .font(Metrics.Font.monoCaption)
                    .foregroundStyle(Palette.Text.secondary.color)
                    .accessibilityIdentifier("applyPatch.totals")
            }
        }
    }

    @ViewBuilder
    private var checkStatus: some View {
        switch session.check {
        case .idle:
            EmptyView()
        case .checking:
            HStack(spacing: Metrics.Spacing.s) {
                ProgressView().controlSize(.small)
                Text("git apply --check…")
                    .font(Metrics.Font.monoCaption)
                    .foregroundStyle(Palette.Text.secondary.color)
            }
        case .passed:
            Label("git apply --check: the patch applies cleanly.", systemImage: "checkmark.circle.fill")
                .font(Metrics.Font.body)
                .foregroundStyle(Palette.Status.added.ink.color)
                .accessibilityIdentifier("applyPatch.checkPassed")
        case let .failed(message):
            ScrollView {
                CommandOutputBox(command: nil, lines: message.components(separatedBy: "\n").map { ErrorReport.Line($0) })
            }
            .frame(maxHeight: Metrics.Sheet.patchErrorHeight)
            .background(Palette.Surface.well.color, in: RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(message)
            .accessibilityIdentifier("applyPatch.error")
        }
    }
}

extension View {
    func workingCopyToolsPresentation(_ viewModel: RepositoryViewModel) -> some View {
        modifier(WorkingCopyToolsPresentation(viewModel: viewModel))
    }
}

private struct WorkingCopyToolsPresentation: ViewModifier {
    @Bindable var viewModel: RepositoryViewModel

    func body(content: Content) -> some View {
        content
            .sheet(item: $viewModel.ignoreDraft) { IgnoreRuleSheet(viewModel: viewModel, draft: $0) }
            .sheet(item: $viewModel.patchSession) { ApplyPatchSheet(session: $0) }
            .morkConfirmation(item: $viewModel.notice) { notice in
                .notice(title: notice.title, message: notice.message, identifier: "notice.ok")
            }
    }
}
