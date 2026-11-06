import MorkDomain
import Foundation

public struct CommitTreeDependencies: Sendable {
    public let loadTreeEntries: LoadTreeEntriesUseCaseProtocol
    public let loadFileAtRevision: LoadFileAtRevisionUseCaseProtocol
    public let saveFileAtRevision: SaveFileAtRevisionUseCaseProtocol
    public let panels: FilePanelsProtocol

    public init(
        loadTreeEntries: LoadTreeEntriesUseCaseProtocol,
        loadFileAtRevision: LoadFileAtRevisionUseCaseProtocol,
        saveFileAtRevision: SaveFileAtRevisionUseCaseProtocol,
        panels: FilePanelsProtocol
    ) {
        self.loadTreeEntries = loadTreeEntries
        self.loadFileAtRevision = loadFileAtRevision
        self.saveFileAtRevision = saveFileAtRevision
        self.panels = panels
    }
}
