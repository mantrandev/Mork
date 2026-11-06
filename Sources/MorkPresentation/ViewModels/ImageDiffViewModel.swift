import MorkDomain
import Foundation
import Observation

@MainActor
@Observable
public final class ImageDiffViewModel {
    public enum Mode: String, CaseIterable, Identifiable, Sendable {
        case sideBySide = "Side by Side"
        case swipe = "Swipe"
        case onionSkin = "Onion Skin"

        public var id: String { rawValue }
    }

    public let sources: ImageDiffSources
    public private(set) var state: Loadable<ImageDiffPreview> = .idle
    public var mode: Mode = .sideBySide
    public var split = 0.5
    public var opacity = 0.5

    private let loadImageDiff: LoadImageDiffUseCaseProtocol
    @ObservationIgnored private var task: Task<Void, Never>?

    public init(sources: ImageDiffSources, loadImageDiff: LoadImageDiffUseCaseProtocol) {
        self.sources = sources
        self.loadImageDiff = loadImageDiff
    }

    public var canOverlay: Bool {
        if case let .loaded(preview) = state { preview.canOverlay } else { false }
    }

    public var visibleMode: Mode { canOverlay ? mode : .sideBySide }

    public func reload() {
        task?.cancel()
        if case .idle = state { state = .loading }
        let load = loadImageDiff
        let sources = sources
        task = Task { [weak self] in
            let result: Loadable<ImageDiffPreview>
            do {
                let diff = try await load.execute(sources: sources, limit: ImageBlob.limit)
                result = .loaded(await Task.detached(priority: .userInitiated) { ImageDecoder.preview(diff, path: sources.path) }.value)
            } catch {
                result = .failed(error.localizedDescription)
            }
            guard let self, !Task.isCancelled else { return }
            self.state = result
        }
    }

    public func waitForLoad() async {
        await task?.value
    }

    public func cancel() {
        task?.cancel()
        task = nil
    }
}

extension RepositoryViewModel {
    func refreshImageDiff() {
        let sources: ImageDiffSources? = switch selection {
        case let .file(change, staged) where ImageFileType.isImage(change.path) && !change.isConflicted: .change(change, staged: staged)
        case let .commitFile(commit, file) where ImageFileType.isImage(file.path): .commitFile(commit, file)
        default: nil
        }
        guard let sources else {
            if imageDiff != nil {
                imageDiff?.cancel()
                imageDiff = nil
            }
            return
        }
        if imageDiff?.sources != sources {
            imageDiff?.cancel()
            imageDiff = ImageDiffViewModel(sources: sources, loadImageDiff: dependencies.exploration.loadImageDiff)
        }
        imageDiff?.reload()
    }
}
