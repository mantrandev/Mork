import MorkDomain
import SwiftUI

struct CloneSheet: View {
    @Bindable var app: AppViewModel
    @State private var source = ""
    @State private var parentPath: String
    @State private var name = ""
    @State private var isNameEdited = false

    init(app: AppViewModel) {
        self.app = app
        let parent = app.recentRepositories.first?.deletingLastPathComponent() ?? FileManager.default.homeDirectoryForCurrentUser
        _parentPath = State(initialValue: (parent.path as NSString).abbreviatingWithTildeInPath)
    }

    private var destination: URL {
        URL(fileURLWithPath: (parentPath as NSString).expandingTildeInPath).appendingPathComponent(name)
    }

    private var canClone: Bool {
        !app.isCloning
            && !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !parentPath.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        DialogScaffold(
            kind: .form,
            glyph: "square.and.arrow.down",
            title: "Clone Repository",
            width: Metrics.Sheet.wideWidth
        ) {
            VStack(alignment: .leading, spacing: Metrics.Sheet.rowSpacing) {
                CloneAccountPicker(viewModel: app.cloneAccounts) { url in
                    source = url
                    isNameEdited = false
                    name = CloneRepositoryUseCase.suggestedDirectoryName(for: url)
                }
                .disabled(app.isCloning)
                VStack(alignment: .leading, spacing: Metrics.Sheet.rowSpacing) {
                    DialogLabeledRow("URL") {
                        DialogTextField(placeholder: "https://github.com/user/repo.git or /path/to/repo", text: $source, identifier: "clone.url", isMonospaced: true)
                            .onChange(of: source) { _, value in
                                if !isNameEdited { name = CloneRepositoryUseCase.suggestedDirectoryName(for: value) }
                            }
                    }
                    DialogLabeledRow("Into") {
                        HStack(spacing: Metrics.Spacing.s) {
                            DialogTextField(placeholder: "~/Developer", text: $parentPath, identifier: "clone.parent")
                            Button("Choose…") {
                                if let url = FolderPicker.pick(prompt: "Choose") { parentPath = url.path }
                            }
                            .buttonStyle(.morkSecondary)
                            .accessibilityIdentifier("clone.choose")
                        }
                    }
                    DialogLabeledRow("Name") {
                        DialogTextField(placeholder: "repo", text: Binding(get: { name }, set: { name = $0; isNameEdited = true }), identifier: "clone.name")
                    }
                }
                .disabled(app.isCloning)
            }
            if app.isCloning, let percent = app.cloneProgress.percent {
                DialogProgressBar(fraction: Double(percent) / 100)
            } else if app.isCloning {
                DialogProgressBar(fraction: nil)
            }
            CommandStrip(command: DialogCommands.line(["clone", "--progress", source.isEmpty ? "<url>" : source, destination.path]), note: progressNote)
            if app.isCloning || !app.cloneProgress.lines.isEmpty {
                LogLinesList(lines: app.cloneProgress.lines)
                    .frame(height: Metrics.Sheet.cloneLogHeight)
                    .background(Palette.Surface.well.color)
                    .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous))
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("clone.progress")
            }
            if let message = app.cloneErrorMessage {
                DialogNote(text: message, tone: .danger)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("clone.error")
            }
        } buttons: {
            DialogCancelButton(title: app.isCloning ? "Stop" : "Cancel", identifier: "clone.cancel") {
                if app.isCloning { app.cancelClone() } else { app.isCloneSheetPresented = false }
            }
            DialogConfirmButton(title: "Clone", identifier: "clone.confirm") {
                let source = source
                let destination = destination
                Task { await app.clone(source: source, destination: destination) }
            }
            .disabled(!canClone)
        }
        .interactiveDismissDisabled(app.isCloning)
        .task { await app.cloneAccounts.load() }
    }

    private var progressNote: String {
        guard app.isCloning else { return DialogCommandLine.confirmNote }
        return app.cloneProgress.percent.map { "\($0) %" } ?? "running"
    }
}
