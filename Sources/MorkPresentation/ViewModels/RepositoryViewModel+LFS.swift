import MorkDomain
import Foundation

extension RepositoryViewModel {
    public var lfsInstallation: LFSInstallation? { advanced.lfsInstallation }
    public var isLFSInstalled: Bool { advanced.lfsInstallation?.isInstalled ?? false }

    public func isLFSFile(_ path: String) -> Bool {
        advanced.lfsPaths.contains(path)
    }

    public func isLFSFile(_ path: String, in commit: Commit) -> Bool {
        guard let files = advanced.commitLFSFiles, files.commit == commit.hash else { return false }
        return files.paths.contains(path)
    }

    public func detectLFS() async {
        if let running = advanced.lfsDetection {
            await running.value
            return
        }
        let load = dependencies.advanced.lfs.loadInstallation
        let task = Task { [weak self] in
            let installation = await load.execute()
            guard let self else { return }
            if self.advanced.lfsInstallation != installation { self.advanced.lfsInstallation = installation }
            self.advanced.lfsDetection = nil
        }
        advanced.lfsDetection = task
        await task.value
    }

    public func showLFSInstallHint() async {
        await detectLFS()
        guard !isLFSInstalled else { return }
        notice = Notice(
            title: "Git LFS Is Not Installed",
            message: "git lfs version failed, so the git-lfs add-on is missing. Mork never installs tools. Install it in Terminal with:\n\n\(LFSInstallation.installCommand)\n\nThen choose Repository ▸ Git LFS again."
        )
    }

    public func detectLFSIfNeeded() async {
        guard advanced.lfsInstallation == nil else { return }
        await detectLFS()
    }

    func scheduleLFSMarkers() {
        advanced.lfsMarkers?.cancel()
        let paths = changes.map(\.path)
        guard !paths.isEmpty else {
            if !advanced.lfsPaths.isEmpty { advanced.lfsPaths = [] }
            return
        }
        let load = dependencies.advanced.lfs.loadFiles
        advanced.lfsMarkers = Task { [weak self] in
            let found = (try? await load.execute(paths: paths, revision: nil)) ?? []
            guard !Task.isCancelled, let self else { return }
            if self.advanced.lfsPaths != found { self.advanced.lfsPaths = found }
        }
    }

    public func waitForLFSMarkers() async {
        await advanced.lfsMarkers?.value
    }

    public func loadLFSMarkers(for summary: CommitSummary) async {
        guard advanced.commitLFSFiles?.commit != summary.commit.hash else { return }
        let paths = summary.files.map(\.path)
        let load = dependencies.advanced.lfs.loadFiles
        let found = (try? await load.execute(paths: paths, revision: summary.commit.hash)) ?? []
        advanced.commitLFSFiles = CommitLFSFiles(commit: summary.commit.hash, paths: found)
    }

    public func initializeLFS() async {
        if await perform({ try await $0.advanced.lfs.initialize.execute() }) {
            notice = Notice(
                title: "Git LFS Initialized",
                message: "git lfs install --local added the LFS filters and the pre-push hook to this repository. Next, track a pattern such as *.psd and commit .gitattributes."
            )
        }
    }

    public func requestLFSTrack() {
        advanced.lfsSheet = .track
    }

    @discardableResult
    public func trackLFS(pattern: String) async -> Bool {
        await perform { try await $0.advanced.lfs.track.execute(pattern: pattern) }
    }

    public func lfsPattern(forFile path: String) -> String {
        TrackLFSPatternUseCase.pattern(forFile: path)
    }

    public func trackFileTypeWithLFS(_ path: String) async {
        await trackLFS(pattern: lfsPattern(forFile: path))
    }

    public func requestLFSUntrack() async {
        advanced.lfsSheet = .untrack
        await loadLFSPatterns()
    }

    public func loadLFSPatterns() async {
        if case .loaded = advanced.lfsPatterns {} else { advanced.lfsPatterns = .loading }
        let load = dependencies.advanced.lfs.loadPatterns
        do {
            advanced.lfsPatterns = .loaded(try await reading { try await load.execute() })
        } catch {
            advanced.lfsPatterns = .failed(error.localizedDescription)
        }
    }

    public func untrackLFS(pattern: String) async {
        await perform { try await $0.advanced.lfs.untrack.execute(pattern: pattern) }
        await loadLFSPatterns()
    }

    public func requestLFSTransfer(_ transfer: LFSTransfer) {
        advanced.lfsTransfer = LFSTransferState()
        advanced.lfsSheet = .transfer(transfer)
    }

    public func transferLFS(_ transfer: LFSTransfer) async {
        guard !advanced.lfsTransfer.isRunning else { return }
        advanced.lfsTransfer = LFSTransferState()
        advanced.lfsTransfer.isRunning = true
        defer { advanced.lfsTransfer.isRunning = false }
        let (lines, continuation) = AsyncStream<String>.makeStream()
        let run = dependencies.advanced.lfs.transfer
        let task = Task {
            defer { continuation.finish() }
            try await run.execute(transfer) { continuation.yield($0) }
        }
        for await line in lines {
            advanced.lfsTransfer.progress.append(line)
        }
        let succeeded = await perform { _ in try await task.value }
        if !succeeded { advanced.lfsTransfer.failure = "\(transfer.commandLine) failed. See the Git Console for the full output." }
    }

    nonisolated static func lfsPointerChange(of text: String) -> LFSPointerChange? {
        guard text.utf8.count <= 4_096 else { return nil }
        return LFSPointerChange.parse(diff: text)
    }
}
