import MorkPresentation
import Foundation

struct LaunchFilePanels: FilePanelsProtocol {
    private let openFile: URL?
    private let saveFile: URL?
    private let fallback = AppKitFilePanels()

    init(openFile: URL?, saveFile: URL?) {
        self.openFile = openFile
        self.saveFile = saveFile
    }

    init(options: LaunchOptions) {
        self.init(openFile: options.openPanelFile, saveFile: options.savePanelFile)
    }

    func choosePatchFile() async -> URL? {
        if let openFile { return openFile }
        return await fallback.choosePatchFile()
    }

    func chooseDestination(suggestedName: String) async -> URL? {
        if let saveFile { return saveFile }
        return await fallback.chooseDestination(suggestedName: suggestedName)
    }
}

struct LaunchFolderPanel: FolderPanelProtocol {
    private let folder: URL?
    private let fallback = AppKitFolderPanel()

    init(options: LaunchOptions) {
        folder = options.folderPanelPath
    }

    func chooseFolder(prompt: String) async -> URL? {
        if let folder { return folder }
        return await fallback.chooseFolder(prompt: prompt)
    }
}
