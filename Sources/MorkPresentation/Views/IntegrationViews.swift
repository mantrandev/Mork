import AppKit
import MorkDomain
import SwiftUI

@MainActor
enum AppIcons {
    private static var cache: [String: NSImage] = [:]

    static func icon(atPath path: String?) -> NSImage? {
        guard let path else { return nil }
        if let cached = cache[path] { return cached }
        let image = NSWorkspace.shared.icon(forFile: path)
        image.size = NSSize(width: Metrics.Icon.column, height: Metrics.Icon.column)
        cache[path] = image
        return image
    }
}

struct IntegrationFileMenu: View {
    let viewModel: RepositoryViewModel
    let path: String
    var diffTarget: ExternalDiffTarget?
    var line: Int?
    var canOpenFile = true

    var body: some View {
        if let diffTarget {
            Button("Open in External Diff Tool") { viewModel.openInDiffTool(path: path, target: diffTarget) }
                .disabled(viewModel.externalTools.run(for: path) != nil)
                .help(viewModel.diffToolName.map { "git difftool --tool with \($0)" } ?? "Pick a diff tool in Settings ▸ Integration")
                .accessibilityIdentifier("file.externalDiff")
        }
        Button(Self.editorTitle(viewModel.editorName, line: line)) { Task { await viewModel.openInEditor(path: path, line: line) } }
            .disabled(!canOpenFile)
            .accessibilityIdentifier("file.openInEditor")
    }

    static func editorTitle(_ editor: String?, line: Int?) -> String {
        "Open in \(editor ?? "External Editor")" + (line.map { " at Line \($0)" } ?? "")
    }
}

struct DiffLineEditorMenu: View {
    let viewModel: RepositoryViewModel
    let line: DiffLine

    var body: some View {
        if case let .file(change, _) = viewModel.selection, let number = line.newNumber ?? line.oldNumber {
            Button(IntegrationFileMenu.editorTitle(viewModel.editorName, line: number)) {
                Task { await viewModel.openInEditor(path: change.path, line: number) }
            }
            .accessibilityIdentifier("diff.line.openInEditor")
        }
    }
}

struct MergeToolBar: View {
    let repository: RepositoryViewModel
    let resolver: ConflictResolverViewModel

    var body: some View {
        let path = resolver.path
        VStack(alignment: .leading, spacing: Metrics.ChangeRow.gap) {
            if let run = repository.externalTools.run(for: path), run.role == .merge {
                HStack(spacing: Metrics.Spacing.s) {
                    ProgressView().controlSize(.small)
                    Text("Waiting for \(run.tool)… (close the tool to continue)")
                        .font(Metrics.Font.body)
                        .foregroundStyle(Palette.Text.primary.color)
                        .accessibilityIdentifier("conflict.mergeTool.waiting")
                    Spacer()
                    Button("Cancel") { repository.cancelExternalTool(at: path) }
                        .buttonStyle(.mork(.secondary, size: .small))
                        .help("Stop git mergetool and the tool, and put the conflicted file back as it was")
                        .accessibilityIdentifier("conflict.mergeTool.cancel")
                }
            }
            if let message = repository.externalTools.message(for: path) {
                HStack(alignment: .top, spacing: Metrics.ChangeRow.gap) {
                    Image(systemName: "xmark.octagon.fill").foregroundStyle(Palette.Status.deleted.ink.color)
                    Text(message)
                        .font(Metrics.Font.monoCaption)
                        .foregroundStyle(Palette.Text.primary.color)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("conflict.mergeTool.message")
                    Spacer()
                    PanelIconButton(title: "Dismiss", systemImage: "xmark", identifier: "conflict.mergeTool.dismiss") { repository.externalTools.dismissMessage(for: path) }
                }
                .padding(Metrics.ChangeRow.gap)
                .background(Palette.Status.deleted.tint.color, in: RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous))
            }
        }
    }
}

struct OpenInMergeToolButton: View {
    let repository: RepositoryViewModel
    let resolver: ConflictResolverViewModel

    var body: some View {
        if resolver.canOpenInMergeTool {
            Button("Open in \(repository.mergeToolName ?? "Merge Tool")") { repository.openInMergeTool(resolver.change) }
                .buttonStyle(.mork(.secondary, size: .small))
                .disabled(repository.externalTools.run(for: resolver.path) != nil)
                .help("git mergetool --no-prompt --tool=… -- \(ShellWords.quote(resolver.path))")
                .accessibilityIdentifier("conflict.mergeTool.open")
        }
    }
}
