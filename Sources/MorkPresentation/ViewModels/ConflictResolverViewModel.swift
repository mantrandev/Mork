import MorkDomain
import Foundation
import Observation

public enum ConflictBlockState: Equatable, Sendable {
    case unresolved
    case chosen(ConflictChoice)
    case editedByHand
}

public struct ConflictBlockView: Identifiable, Equatable, Sendable {
    public let block: ConflictBlock
    public let ours: [String]
    public let base: [String]?
    public let baseLabel: String?
    public let baseCaption: String?
    public let theirs: [String]
    public internal(set) var state = ConflictBlockState.unresolved
    let oursText: String
    let baseText: String?
    let theirsText: String

    public var id: Int { block.index }

    init(_ block: ConflictBlock, bases: ConflictBases) {
        self.block = block
        let base = block.base.map { ($0, block.baseLabel ?? "") } ?? bases.base(of: block)
        ours = ConflictText.lines(block.ours)
        self.base = base.map { ConflictText.lines($0.0) }
        baseLabel = base?.1
        baseCaption = base.flatMap { Self.caption(ofBaseLabel: $0.1) }
        theirs = ConflictText.lines(block.theirs)
        oursText = ours.joined(separator: "\n")
        baseText = self.base.map { $0.joined(separator: "\n") }
        theirsText = theirs.joined(separator: "\n")
    }
}

extension ConflictBlockView {
    static let shortShaLength = 7

    static func caption(ofBaseLabel label: String) -> String? {
        guard !label.isEmpty, label.caseInsensitiveCompare("base") != .orderedSame else { return nil }
        let isSha = label.count >= shortShaLength && label.allSatisfy(\.isHexDigit)
        return isSha ? String(label.prefix(shortShaLength)) : label
    }
}

struct ConflictBases: Sendable {
    private let bases: [Int: (String, String)]

    init(document: ConflictDocument?, withBase: ConflictDocument?) {
        var bases: [Int: (String, String)] = [:]
        if let document, let withBase, document.blocks.count == withBase.blocks.count {
            for (plain, merged) in zip(document.blocks, withBase.blocks) {
                guard let base = merged.base, plain.ours == merged.ours, plain.theirs == merged.theirs else { continue }
                bases[plain.index] = (base, merged.baseLabel ?? "")
            }
        }
        self.bases = bases
    }

    func base(of block: ConflictBlock) -> (String, String)? {
        bases[block.index]
    }
}

public struct ConflictResultTints: Equatable, Sendable {
    public struct Run: Equatable, Sendable {
        public let range: NSRange
        public let origin: ConflictLineOrigin

        public init(range: NSRange, origin: ConflictLineOrigin) {
            self.range = range
            self.origin = origin
        }
    }

    public let revision: Int
    public let origins: [ConflictLineOrigin]
    public let runs: [Run]

    public init(revision: Int = 0, origins: [ConflictLineOrigin] = [], runs: [Run] = []) {
        self.revision = revision
        self.origins = origins
        self.runs = runs
    }

    init(revision: Int, text: String, origins: [ConflictLineOrigin]) {
        var runs: [Run] = []
        var start = 0
        var offset = 0
        var line = 0
        func close(at end: Int) {
            guard line < origins.count else { return }
            let origin = origins[line]
            if let last = runs.last, last.origin == origin, NSMaxRange(last.range) == start {
                runs[runs.count - 1] = Run(range: NSRange(location: last.range.location, length: end - last.range.location), origin: origin)
            } else {
                runs.append(Run(range: NSRange(location: start, length: end - start), origin: origin))
            }
            line += 1
            start = end
        }
        for unit in text.utf16 {
            offset += 1
            if unit == UInt16(UInt8(ascii: "\n")) { close(at: offset) }
        }
        if offset > start { close(at: offset) }
        self.init(revision: revision, origins: origins, runs: runs)
    }
}

@MainActor
@Observable
public final class ConflictResolverViewModel {
    public typealias Perform = @MainActor (@escaping @Sendable (ConflictDependencies) async throws -> Void) async -> Bool

    public enum State: Equatable, Sendable {
        case loading
        case loaded(ConflictFile)
        case failed(String)
    }

    private struct Loaded: Sendable {
        let file: ConflictFile
        let blocks: [ConflictBlockView]
        let text: String
        let tracker: ConflictEditTracker?
        let origins: [ConflictLineOrigin]
    }

    private struct Choice: Sendable {
        let choice: ConflictChoice
        let text: String
    }

    private struct Analysis: Sendable {
        let states: [ConflictBlockState]
        let unresolvedCount: Int
        let markerCount: Int
        let hasChanges: Bool
        let tints: ConflictResultTints
    }

    public private(set) var change: FileChange
    public private(set) var state: State = .loading
    public private(set) var blocks: [ConflictBlockView] = []
    public private(set) var originalDocument: ConflictDocument?
    public private(set) var resultText = ""
    public private(set) var resultRevision = 0
    public private(set) var resultTints = ConflictResultTints()
    public private(set) var documentVersion = 0
    public private(set) var unresolvedCount = 0
    public private(set) var markerCount = 0
    public private(set) var hasChanges = false
    public private(set) var isWorking = false
    public private(set) var sideHint: String?
    public private(set) var confirmationSaves = false
    public var pendingMarkResolved: Int?

    @ObservationIgnored private let loadConflict: LoadConflictUseCaseProtocol
    @ObservationIgnored private let debounce: Duration
    @ObservationIgnored private let perform: Perform
    @ObservationIgnored private var originalText = ""
    @ObservationIgnored private var tracker: ConflictEditTracker?
    @ObservationIgnored private var choices: [Int: Choice] = [:]
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var analysisTask: Task<Void, Never>?

    init(change: FileChange, loadConflict: LoadConflictUseCaseProtocol, debounce: Duration, perform: @escaping Perform) {
        self.change = change
        self.loadConflict = loadConflict
        self.debounce = debounce
        self.perform = perform
    }

    public var path: String { change.path }
    public var kind: ConflictKind? { change.conflictKind }
    public var fileResolutions: [ConflictFileResolution] { kind?.resolutions ?? [] }
    public var canMarkResolved: Bool { kind?.hasContentConflict == true }
    public var canOpenInMergeTool: Bool { kind?.hasContentConflict == true && file?.document != nil }
    public var isResultEditable: Bool { kind?.hasContentConflict == true && originalDocument != nil }

    public var file: ConflictFile? {
        guard case let .loaded(file) = state else { return nil }
        return file
    }

    public var hasBlocksToResolve: Bool { originalDocument?.blocks.isEmpty == false }
    public var canSave: Bool { isResultEditable && hasBlocksToResolve && (hasChanges || markerCount == 0) && !isWorking }
    public var typedMarkerCount: Int { max(0, markerCount - unresolvedCount) }

    public var progressText: String {
        guard unresolvedCount > 0 || typedMarkerCount > 0 else { return "Every block is resolved." }
        let remaining = "\(unresolvedCount) \(unresolvedCount == 1 ? "block still has" : "blocks still have") conflict markers"
        return typedMarkerCount > 0 ? "\(remaining), and \(typedMarkerCount) typed by hand." : "\(remaining)."
    }

    public func canChoose(_ block: Int) -> Bool {
        blocks.indices.contains(block) && blocks[block].state == .unresolved && !isWorking
    }

    public func choose(_ choice: ConflictChoice, for block: Int) {
        guard canChoose(block), let document = originalDocument else { return }
        let chosen = blocks[block].block
        guard let range = resultText.range(of: chosen.raw, options: .literal) else { return }
        let replacement = chosen.text(for: choice, lineEnding: document.lineEnding)
        var text = resultText
        text.replaceSubrange(range, with: replacement)
        choices[block] = Choice(choice: choice, text: replacement)
        setResult(text, after: .zero)
    }

    public func updateResult(_ text: String) {
        setResult(text, after: debounce)
    }

    public func reset() {
        choices = [:]
        setResult(originalText, after: .zero)
    }

    public func save() async {
        await analysisTask?.value
        guard canSave else { return }
        if markerCount > 0 {
            confirmationSaves = true
            pendingMarkResolved = markerCount
            return
        }
        await saveText(force: false)
    }

    public func resolve(_ resolution: ConflictFileResolution) async {
        guard fileResolutions.contains(resolution), !isWorking else { return }
        let change = change
        await run { try await $0.resolveConflictFile.execute(change: change, resolution: resolution) }
    }

    public func markResolved() async {
        confirmationSaves = false
        if let remaining = file?.document?.blocks.count, remaining > 0 {
            pendingMarkResolved = remaining
            return
        }
        await markResolved(force: false)
    }

    public func confirmMarkResolved() async {
        let saves = confirmationSaves
        pendingMarkResolved = nil
        confirmationSaves = false
        if saves {
            await saveText(force: true)
        } else {
            await markResolved(force: true)
        }
    }

    public func waitUntilIdle() async {
        await loadTask?.value
        await analysisTask?.value
    }

    func reload(_ change: FileChange, isRebasing: Bool) {
        self.change = change
        sideHint = isRebasing
            ? "During a rebase, Ours is the branch you are rebasing onto and Theirs is your commit being replayed."
            : nil
        loadTask?.cancel()
        let loadConflict = loadConflict
        loadTask = Task { [weak self] in
            let result: Result<Loaded, Error>
            do {
                let file = try await loadConflict.execute(change: change)
                result = .success(await Self.prepare(file))
            } catch {
                result = .failure(error)
            }
            guard !Task.isCancelled, let self, self.change == change else { return }
            self.apply(result)
        }
    }

    private func apply(_ result: Result<Loaded, Error>) {
        switch result {
        case let .success(loaded):
            let isSameDocument = file?.document == loaded.file.document
            state = .loaded(loaded.file)
            guard !isSameDocument else { return }
            analysisTask?.cancel()
            originalDocument = loaded.file.document
            originalText = loaded.text
            tracker = loaded.tracker
            choices = [:]
            blocks = loaded.blocks
            unresolvedCount = loaded.blocks.count
            markerCount = loaded.blocks.count
            hasChanges = false
            resultText = loaded.text
            resultRevision += 1
            resultTints = ConflictResultTints(revision: resultRevision, text: loaded.text, origins: loaded.origins)
            documentVersion += 1
        case let .failure(error):
            state = .failed(error.localizedDescription)
            analysisTask?.cancel()
            originalDocument = nil
            originalText = ""
            tracker = nil
            choices = [:]
            blocks = []
            unresolvedCount = 0
            markerCount = 0
            hasChanges = false
            resultText = ""
            resultRevision += 1
            resultTints = ConflictResultTints(revision: resultRevision)
            documentVersion += 1
        }
    }

    private func setResult(_ text: String, after delay: Duration) {
        resultText = text
        resultRevision += 1
        analysisTask?.cancel()
        guard let tracker else { return }
        let revision = resultRevision
        let original = originalText
        let blocks = blocks.map(\.block)
        let choices = choices
        analysisTask = Task { [weak self] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
            }
            let analysis = await Task.detached(priority: .userInitiated) {
                Self.analyze(text, revision: revision, original: original, tracker: tracker, blocks: blocks, choices: choices)
            }.value
            guard !Task.isCancelled, let self, self.resultRevision == revision else { return }
            self.apply(analysis)
        }
    }

    private func apply(_ analysis: Analysis) {
        if blocks.map(\.state) != analysis.states, blocks.count == analysis.states.count {
            var updated = blocks
            for index in updated.indices { updated[index].state = analysis.states[index] }
            blocks = updated
        }
        unresolvedCount = analysis.unresolvedCount
        markerCount = analysis.markerCount
        hasChanges = analysis.hasChanges
        resultTints = analysis.tints
    }

    private func saveText(force: Bool) async {
        guard canMarkResolved else { return }
        let path = path
        let text = resultText
        await run { try await $0.saveConflictText.execute(path: path, text: text, force: force) }
    }

    private func markResolved(force: Bool) async {
        guard canMarkResolved else { return }
        let path = path
        await run { try await $0.markConflictResolved.execute(path: path, force: force) }
    }

    private func run(_ body: @escaping @Sendable (ConflictDependencies) async throws -> Void) async {
        isWorking = true
        defer { isWorking = false }
        _ = await perform(body)
    }

    nonisolated private static func analyze(_ text: String, revision: Int, original: String, tracker: ConflictEditTracker, blocks: [ConflictBlock], choices: [Int: Choice]) -> Analysis {
        let current = ConflictParser.parse(text).blocks
        var cursor = 0
        var states: [ConflictBlockState] = []
        for block in blocks {
            if let match = current[cursor...].firstIndex(where: { $0.raw == block.raw }) {
                states.append(.unresolved)
                cursor = match + 1
            } else if let choice = choices[block.index], choice.text.isEmpty || text.range(of: choice.text, options: .literal) != nil {
                states.append(.chosen(choice.choice))
            } else {
                states.append(.editedByHand)
            }
        }
        return Analysis(
            states: states,
            unresolvedCount: states.filter { $0 == .unresolved }.count,
            markerCount: current.count,
            hasChanges: text != original,
            tints: ConflictResultTints(revision: revision, text: text, origins: tracker.origins(of: text))
        )
    }

    nonisolated private static func prepare(_ file: ConflictFile) async -> Loaded {
        await Task.detached(priority: .userInitiated) {
            let bases = ConflictBases(document: file.document, withBase: file.documentWithBase)
            guard let document = file.document else { return Loaded(file: file, blocks: [], text: "", tracker: nil, origins: []) }
            let text = document.text
            let tracker = ConflictEditTracker(document: document)
            let blocks = document.blocks.map { ConflictBlockView($0, bases: bases) }
            return Loaded(file: file, blocks: blocks, text: text, tracker: tracker, origins: tracker.origins(of: text))
        }.value
    }
}
