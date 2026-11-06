import AppKit
import Foundation
import UniformTypeIdentifiers

public struct AppKitFilePanels: FilePanelsProtocol {
    private static let patchTypes = ["patch", "diff"].compactMap { UTType(filenameExtension: $0) }

    public init() {}

    public func choosePatchFile() async -> URL? {
        await MainActor.run {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = Self.patchTypes
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.message = "Choose a .patch or .diff file to preview."
            panel.prompt = "Preview"
            return panel.runModal() == .OK ? panel.url : nil
        }
    }

    public func chooseDestination(suggestedName: String) async -> URL? {
        await MainActor.run {
            let panel = NSSavePanel()
            panel.allowedContentTypes = Self.patchTypes
            panel.nameFieldStringValue = suggestedName
            panel.canCreateDirectories = true
            panel.message = "Save the commit as a patch (git format-patch)."
            return panel.runModal() == .OK ? panel.url : nil
        }
    }
}

public struct AppKitFolderPanel: FolderPanelProtocol {
    public init() {}

    public func chooseFolder(prompt: String) async -> URL? {
        await MainActor.run { FolderPicker.pick(prompt: prompt) }
    }
}
