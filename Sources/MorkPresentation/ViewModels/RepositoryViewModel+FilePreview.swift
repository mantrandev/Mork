import Foundation

extension RepositoryViewModel {
    public var previewedFilePath: String? {
        isPreviewingFile ? selectedFilePath : nil
    }

    public func toggleFilePreview() {
        if conflictWindowPath != nil || selectedConflict != nil {
            toggleConflictWindow()
            return
        }
        isPreviewingFile = !isPreviewingFile && selectedFilePath != nil
    }

    public func closeFilePreview() {
        isPreviewingFile = false
    }
}
