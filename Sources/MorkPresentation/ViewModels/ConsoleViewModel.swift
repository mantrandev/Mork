import MorkDomain
import Foundation
import Observation

@MainActor
@Observable
public final class ConsoleViewModel: GitCommandLogging {
    public static let maxRecords = 500

    public var showsReadCommands = false {
        didSet { if showsReadCommands != oldValue { rebuildVisible() } }
    }
    public var showsLessons = true
    public private(set) var hasVisibleRecords = false

    private var revision = 0
    private var visibleRevision = 0
    @ObservationIgnored private var all = RecordRing(capacity: maxRecords)
    @ObservationIgnored private var visible = RecordRing(capacity: maxRecords)
    @ObservationIgnored private var lessons: [UUID: String?] = [:]
    private let explainCommand: ExplainGitCommandUseCaseProtocol

    public init(explainCommand: ExplainGitCommandUseCaseProtocol) {
        self.explainCommand = explainCommand
    }

    public var records: [GitCommandRecord] {
        _ = revision
        return all.elements
    }

    public var visibleRecords: [GitCommandRecord] {
        _ = visibleRevision
        return visible.elements
    }

    public nonisolated func record(_ record: GitCommandRecord) async {
        let limited = record.limitingOutput(to: ConsoleOutput.maxCharacters)
        await append(limited)
    }

    public func append(_ record: GitCommandRecord) {
        if let dropped = all.append(record) { lessons[dropped.id] = nil }
        revision &+= 1
        guard showsReadCommands || record.kind == .write else { return }
        visible.append(record)
        visibleRevision &+= 1
        updateHasVisibleRecords()
    }

    private func updateHasVisibleRecords() {
        let value = visible.last != nil
        if hasVisibleRecords != value { hasVisibleRecords = value }
    }

    public func clear() {
        all.removeAll()
        visible.removeAll()
        lessons.removeAll()
        revision &+= 1
        visibleRevision &+= 1
        updateHasVisibleRecords()
    }

    public func explanation(for record: GitCommandRecord) -> String? {
        guard showsLessons else { return nil }
        if let cached = lessons[record.id] { return cached }
        let lesson = record.isShell ? Lessons.customShellCommand : explainCommand.execute(arguments: record.arguments)
        lessons[record.id] = .some(lesson)
        return lesson
    }

    private func rebuildVisible() {
        visible.removeAll()
        for record in all.elements where showsReadCommands || record.kind == .write {
            visible.append(record)
        }
        visibleRevision &+= 1
        updateHasVisibleRecords()
    }
}

struct RecordRing {
    private var storage: [GitCommandRecord] = []
    private var start = 0
    let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        storage.reserveCapacity(capacity)
    }

    var count: Int { storage.count }

    var last: GitCommandRecord? {
        guard !storage.isEmpty else { return nil }
        return storage[(start + storage.count - 1) % storage.count]
    }

    var elements: [GitCommandRecord] {
        Array(storage[start...] + storage[..<start])
    }

    @discardableResult
    mutating func append(_ record: GitCommandRecord) -> GitCommandRecord? {
        guard storage.count == capacity else {
            storage.append(record)
            return nil
        }
        let dropped = storage[start]
        storage[start] = record
        start = (start + 1) % capacity
        return dropped
    }

    mutating func removeAll() {
        storage.removeAll(keepingCapacity: true)
        start = 0
    }
}
