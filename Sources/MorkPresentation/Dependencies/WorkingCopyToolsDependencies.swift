import MorkDomain
import Foundation

public protocol FilePanelsProtocol: Sendable {
    func choosePatchFile() async -> URL?
    func chooseDestination(suggestedName: String) async -> URL?
}

public struct WorkingCopyToolsDependencies: Sendable {
    public let applyLines: ApplyLinesUseCaseProtocol
    public let addIgnoreRule: AddIgnoreRuleUseCaseProtocol
    public let loadPatchPreview: LoadPatchPreviewUseCaseProtocol
    public let checkPatch: CheckPatchUseCaseProtocol
    public let applyPatch: ApplyPatchUseCaseProtocol
    public let createPatch: CreatePatchUseCaseProtocol
    public let loadIgnoredFiles: LoadIgnoredFilesUseCaseProtocol
    public let stageIgnoredFiles: StageIgnoredFilesUseCaseProtocol
    public let panels: FilePanelsProtocol

    public init(
        applyLines: ApplyLinesUseCaseProtocol,
        addIgnoreRule: AddIgnoreRuleUseCaseProtocol,
        loadPatchPreview: LoadPatchPreviewUseCaseProtocol,
        checkPatch: CheckPatchUseCaseProtocol,
        applyPatch: ApplyPatchUseCaseProtocol,
        createPatch: CreatePatchUseCaseProtocol,
        loadIgnoredFiles: LoadIgnoredFilesUseCaseProtocol,
        stageIgnoredFiles: StageIgnoredFilesUseCaseProtocol,
        panels: FilePanelsProtocol
    ) {
        self.applyLines = applyLines
        self.addIgnoreRule = addIgnoreRule
        self.loadPatchPreview = loadPatchPreview
        self.checkPatch = checkPatch
        self.applyPatch = applyPatch
        self.createPatch = createPatch
        self.loadIgnoredFiles = loadIgnoredFiles
        self.stageIgnoredFiles = stageIgnoredFiles
        self.panels = panels
    }
}
