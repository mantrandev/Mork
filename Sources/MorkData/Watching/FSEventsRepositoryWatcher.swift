import MorkDomain
import CoreServices
import Foundation

public final class FSEventsRepositoryWatcher: RepositoryWatcherProtocol {
    private let latency: TimeInterval

    public init(latency: TimeInterval = 0.05) {
        self.latency = latency
    }

    public func changes(in root: URL) -> AsyncStream<[String]> {
        let (stream, continuation) = AsyncStream<[String]>.makeStream()
        guard let locations = WatchedLocations(root: root) else {
            continuation.finish()
            return stream
        }
        let handle = EventStreamHandle { paths in
            let relative = paths.compactMap(locations.relativePath)
            if !relative.isEmpty { continuation.yield(relative) }
        }
        guard handle.start(paths: locations.watchedPaths, latency: latency) else {
            continuation.finish()
            return stream
        }
        continuation.onTermination = { _ in handle.stop() }
        return stream
    }
}

struct WatchedLocations: Sendable {
    let root: String
    let gitDirectory: String?
    let commonDirectory: String?

    init?(root url: URL) {
        guard let root = Self.canonicalPath(url.path) else { return nil }
        self.root = root
        let dotGit = root + "/.git"
        guard let contents = try? String(contentsOfFile: dotGit, encoding: .utf8),
              contents.hasPrefix("gitdir:") else {
            gitDirectory = nil
            commonDirectory = nil
            return
        }
        let target = contents.dropFirst("gitdir:".count).trimmingCharacters(in: .whitespacesAndNewlines)
        let gitDirectory = Self.canonicalPath(target.hasPrefix("/") ? target : root + "/" + target)
        self.gitDirectory = gitDirectory
        commonDirectory = gitDirectory.flatMap { directory in
            guard let common = try? String(contentsOfFile: directory + "/commondir", encoding: .utf8) else { return nil }
            let path = common.trimmingCharacters(in: .whitespacesAndNewlines)
            return Self.canonicalPath(path.hasPrefix("/") ? path : directory + "/" + path)
        }
    }

    var watchedPaths: [String] {
        [root] + [gitDirectory, commonDirectory].compactMap { $0 }
    }

    func relativePath(_ path: String) -> String? {
        for directory in [gitDirectory, commonDirectory].compactMap({ $0 }) {
            if let rest = Self.relative(path, to: directory) {
                return rest.isEmpty ? ".git" : ".git/" + rest
            }
        }
        return Self.relative(path, to: root)
    }

    private static func relative(_ path: String, to base: String) -> String? {
        if path == base { return "" }
        guard path.hasPrefix(base + "/") else { return nil }
        return String(path.dropFirst(base.count + 1))
    }

    private static func canonicalPath(_ path: String) -> String? {
        guard let resolved = realpath(path, nil) else { return nil }
        defer { free(resolved) }
        return String(cString: resolved)
    }
}

private final class EventStreamHandle: @unchecked Sendable {
    private let queue = DispatchQueue(label: "mork.watcher")
    private let onEvents: @Sendable ([String]) -> Void
    private var stream: FSEventStreamRef?

    init(onEvents: @escaping @Sendable ([String]) -> Void) {
        self.onEvents = onEvents
    }

    func start(paths: [String], latency: TimeInterval) -> Bool {
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: { info in
                guard let info else { return nil }
                _ = Unmanaged<EventStreamHandle>.fromOpaque(info).retain()
                return UnsafeRawPointer(info)
            },
            release: { info in
                guard let info else { return }
                Unmanaged<EventStreamHandle>.fromOpaque(info).release()
            },
            copyDescription: nil
        )
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagWatchRoot)
        guard let stream = FSEventStreamCreate(nil, Self.callback, &context, paths as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), latency, flags) else {
            return false
        }
        FSEventStreamSetDispatchQueue(stream, queue)
        guard FSEventStreamStart(stream) else {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            return false
        }
        queue.sync { self.stream = stream }
        return true
    }

    func stop() {
        queue.async {
            guard let stream = self.stream else { return }
            self.stream = nil
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }

    private static let callback: FSEventStreamCallback = { _, info, count, paths, _, _ in
        guard let info else { return }
        let handle = Unmanaged<EventStreamHandle>.fromOpaque(info).takeUnretainedValue()
        let list = Unmanaged<CFArray>.fromOpaque(paths).takeUnretainedValue() as? [String] ?? []
        handle.onEvents(Array(list.prefix(count)))
    }
}
