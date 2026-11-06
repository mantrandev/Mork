import Foundation

struct ChangeTableDiff: Equatable {
    let removed: IndexSet
    let inserted: IndexSet

    init(removed: IndexSet, inserted: IndexSet) {
        self.removed = removed
        self.inserted = inserted
    }

    init?(old: [String], new: [String]) {
        let oldSet = Set(old)
        let newSet = Set(new)
        guard oldSet.count == old.count, newSet.count == new.count else { return nil }
        guard old.filter(newSet.contains) == new.filter(oldSet.contains) else { return nil }
        removed = IndexSet(old.indices.filter { !newSet.contains(old[$0]) })
        inserted = IndexSet(new.indices.filter { !oldSet.contains(new[$0]) })
    }

    var isEmpty: Bool { removed.isEmpty && inserted.isEmpty }
}
