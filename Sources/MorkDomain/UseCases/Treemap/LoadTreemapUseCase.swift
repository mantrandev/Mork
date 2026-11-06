import Foundation

public protocol LoadTreemapUseCaseProtocol: Sendable {
    func execute() async throws -> TreemapTree
}

public final class LoadTreemapUseCase: LoadTreemapUseCaseProtocol {
    private let treemap: TreemapRepositoryProtocol

    public init(treemap: TreemapRepositoryProtocol) {
        self.treemap = treemap
    }

    public func execute() async throws -> TreemapTree {
        let files = try await treemap.files(at: "HEAD")
        return await Task.detached(priority: .userInitiated) { TreemapTree.build(files) }.value
    }
}
