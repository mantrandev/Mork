import Observation

@MainActor @Observable final class SidebarSelectionMarks {
    @ObservationIgnored var onActivate: ((RepositoryViewModel.SidebarSelection) -> Void)?

    typealias Item = RepositoryViewModel.SidebarSelection

    @MainActor @Observable final class Mark {
        var isSelected = false
    }

    @ObservationIgnored private var marks: [Item: Mark] = [:]
    @ObservationIgnored private(set) var items: Set<Item> = []

    func mark(for item: Item) -> Mark {
        if let mark = marks[item] { return mark }
        let mark = Mark()
        mark.isSelected = items.contains(item)
        marks[item] = mark
        return mark
    }

    func set(_ next: Set<Item>) {
        guard next != items else { return }
        for item in items.subtracting(next) { marks[item]?.isSelected = false }
        for item in next.subtracting(items) { marks[item]?.isSelected = true }
        items = next
    }
}
