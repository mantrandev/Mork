import Foundation

public protocol FindHiddenFilesUseCaseProtocol: Sendable {
    func execute(failureMessage: String) async throws -> [String]
}

public final class FindHiddenFilesUseCase: FindHiddenFilesUseCaseProtocol {
    private let workingCopy: WorkingCopyRepositoryProtocol

    public init(workingCopy: WorkingCopyRepositoryProtocol) {
        self.workingCopy = workingCopy
    }

    public func execute(failureMessage: String) async throws -> [String] {
        guard failureMessage.contains("would be overwritten by") else { return [] }
        let paths = failureMessage.components(separatedBy: "\n")
            .filter { $0.hasPrefix("\t") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return try await workingCopy.hiddenFiles(among: paths)
    }
}
