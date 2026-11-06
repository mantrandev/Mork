import MorkDomain
import Foundation
import Observation

@MainActor
@Observable
public final class LessonBrowserViewModel: Identifiable {
    public var query = "" {
        didSet { applyQuery() }
    }
    public private(set) var topics: [LessonTopic]
    public var selectedID: String?

    private let catalog: LessonCatalog

    public init(catalog: LessonCatalog = .standard, selecting command: String? = nil) {
        self.catalog = catalog
        topics = catalog.topics
        selectedID = command.flatMap(catalog.topic)?.id ?? catalog.topics.first?.id
    }

    public var selected: LessonTopic? {
        selectedID.flatMap(catalog.topic)
    }

    private func applyQuery() {
        topics = catalog.search(query)
        if !topics.contains(where: { $0.id == selectedID }) {
            selectedID = topics.first?.id
        }
    }
}
