import Foundation

public protocol LoadConflictUseCaseProtocol: Sendable {
    func execute(change: FileChange) async throws -> ConflictFile
}

public final class LoadConflictUseCase: LoadConflictUseCaseProtocol {
    public static let baseLabel = "base"

    private let conflicts: ConflictRepositoryProtocol

    public init(conflicts: ConflictRepositoryProtocol) {
        self.conflicts = conflicts
    }

    public func execute(change: FileChange) async throws -> ConflictFile {
        guard let kind = change.conflictKind else { throw ConflictError.notConflicted(path: change.path) }
        let data = try await conflicts.contents(of: change.path)
        let content = data.map(ConflictParser.content(of:)) ?? .missing
        guard kind.hasContentConflict, case let .text(document) = content else {
            return ConflictFile(path: change.path, kind: kind, content: content)
        }
        let stages = await stages(kind.stages, of: change.path)
        let withBase = await documentWithBase(for: document, named: (change.path as NSString).lastPathComponent, stages: stages)
        return ConflictFile(path: change.path, kind: kind, content: content, stages: stages, documentWithBase: withBase)
    }

    private func stages(_ wanted: [ConflictStage], of path: String) async -> ConflictStages {
        async let base = wanted.contains(.base) ? try? conflicts.stage(.base, of: path) : nil
        async let ours = wanted.contains(.ours) ? try? conflicts.stage(.ours, of: path) : nil
        async let theirs = wanted.contains(.theirs) ? try? conflicts.stage(.theirs, of: path) : nil
        return ConflictStages(base: await base, ours: await ours, theirs: await theirs)
    }

    private func documentWithBase(for document: ConflictDocument, named name: String, stages: ConflictStages) async -> ConflictDocument? {
        guard let first = document.blocks.first, document.blocks.contains(where: { $0.base == nil }),
              let base = stages.base, let ours = stages.ours, let theirs = stages.theirs else { return nil }
        let input = ConflictMergeInput(name: name, ours: ours, base: base, theirs: theirs, oursLabel: first.oursLabel, baseLabel: Self.baseLabel, theirsLabel: first.theirsLabel)
        guard let diff3 = try? await conflicts.mergeFile(input, style: .zdiff3),
              case let .text(withBase) = ConflictParser.content(of: diff3) else { return nil }
        return Self.document(document, takingBasesFrom: withBase.blocks)
    }

    private static func document(_ document: ConflictDocument, takingBasesFrom candidates: [ConflictBlock]) -> ConflictDocument? {
        var unmatched = candidates
        var foundBase = false
        let segments = document.segments.map { segment -> ConflictSegment in
            guard case let .conflict(block) = segment,
                  let match = unmatched.firstIndex(where: { $0.ours == block.ours && $0.theirs == block.theirs }) else { return segment }
            let candidate = unmatched.remove(at: match)
            guard block.base == nil, let base = candidate.base else { return segment }
            foundBase = true
            return .conflict(ConflictBlock(
                index: block.index, ours: block.ours, base: base, theirs: block.theirs,
                oursLabel: block.oursLabel, baseLabel: candidate.baseLabel, theirsLabel: block.theirsLabel, raw: block.raw
            ))
        }
        return foundBase ? ConflictDocument(segments: segments, lineEnding: document.lineEnding) : nil
    }
}
